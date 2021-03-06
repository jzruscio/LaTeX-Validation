#!/usr/bin/ruby

require 'rubygems'
require 'sinatra'
require 'haml'

set :root, File.dirname(__FILE__)
set :public, File.dirname(__FILE__) + '/..'

######################
#Subroutines
#Sort Header info
def get_header(num)
  head_packages = Array.new
  head_header = Array.new
  head_macros = Array.new
  @macros = Array.new
  macros = 0
  for i in 0..num.length-1 do
    if ($latex[num[i]].match(/^\s*$/))
      next
    elsif ($latex[num[i]].match("PLEASE INCLUDE ALL MACROS BELOW"))
      macros = 1
    elsif ($latex[num[i]].match("END MACROS SECTION"))
      macros = 0
    elsif $latex[num[i]].match(/^%/)
      next
    elsif $latex[num[i]].match(/^$/)
      next
    elsif $latex[num[i]].match("\\usepackage")
      type = "usepackage"
      head_packages.push(get_info(type, num[i]))
    elsif $latex[num[i]].match("bibliographystyle")
      type = "bibliographystyle"
      bib = get_info(type, num[i])
    elsif macros == 1
      temp = $latex[num[i]]+"!!!"+num[i].to_s
      $out_tex.puts("#{$latex[num[i]]}\n")
      @macros.push($latex[num[i]])
      head_macros.push(temp)
    else
      temp = $latex[num[i]]+"!!!"+num[i].to_s
      head_header.push(temp)
    end
    check_banned_math(temp)
  end
  check_header(head_header)
  check_packages(head_packages)
  check_bibtex(bib)
end

#Sort Body info
def get_body(num)
  sections = Array.new
  subsections = Array.new
  inline = Array.new
  @math = Hash.new
  @math_dollar = Hash.new
  #for i in 0..num.length-1 do
  i=0
  loop do
    loop do
      break if !($latex[num[i]].match(/^%/))
      i+=1
    end
    if ($latex[num[i]].match("\\\\section"))
      type = "section"
      sec_string = get_info(type, num[i])
      sections.push(sec_string)
      sec_temp=(sec_string.split('!!!'))
      sect = Array.new
      sect.push("Section: #{sec_temp[0]}")
      @math[sec_temp[1].to_i] = sect
      @math_dollar[sec_temp[1].to_i] = sect
    elsif ($latex[num[i]].match("\\\\subsection"))
      type = "subsection"
      sub_string = get_info(type, num[i])
      subsections.push(sub_string)
      subs=(sub_string.split('!!!'))
      sub = Array.new
      sub.push("Subsection: #{subs[0]}")
      @math[subs[1].to_i] = sub
      @math_dollar[subs[1].to_i] = sub
    end
    if ($latex[num[i]].match("\\\\texttt"))
      type = "texttt"
      texttt = get_info(type, num[i]).gsub!(/!!!.*/, '')
      tt = Array["\\texttt{#{texttt}}"]
      @math[num[i]+1] = tt
      @math_dollar[num[i]+1] = tt
      $out_tex.print("\\begin{verbatim}Line: #{num[i]+1}* #{tt}\\end{verbatim}")
      $out_tex.print("#{tt}\n")
    elsif ($latex[num[i]].match("\\\\textsc"))
      type = "textsc"
      smallcaps = get_info(type, num[i]).gsub!(/!!!.*/, '')
      sc = Array["\\textsc{#{smallcaps}}"]
      @math[num[i]+1] = sc
      @math_dollar[num[i]+1] = sc
      $out_tex.print("\\begin{verbatim}Line: #{num[i]+1}* #{sc}\\end{verbatim}")
      $out_tex.print("#{sc}\n")
    end
    if ( ($latex[num[i]].match("[^\$]\\$[^\$]")) || ($latex[num[i]].match("^\\$[^\$]") ) )
      math = ''
      math_index = $latex[num[i]].index(/\$/)+1
      math_letter = $latex[num[i]][math_index,1]
      in_math = true
      j = i
      temp = Array.new
      temp_dollar = Array.new
      loop do
        math_letter = $latex[num[j]][math_index,1]
#print "math_letter = #{math_letter} math_index = #{math_index} in_math = #{in_math} length = #{$latex[num[j]].length}\n"
        if ( math_letter.eql?("\$"))
          if (in_math)
            in_math = false
            temp_banned = math+'!!!'+num[i].to_s
            check_banned_math(temp_banned)
            temp.push(math)
            temp_dollar.push("$#{math}$")
            $out_tex.puts("\\begin{verbatim}Line: #{num[i]+1}* #{math}\\end{verbatim} $#{math}$ \\\\")
            @math_dollar[num[i]+1] = temp_dollar
            @math[num[i]+1] = temp
            math = ''
          elsif (!in_math )
            in_math = true
            math_index+=1
            math_letter = $latex[num[j]][math_index,1]
          end
        end
        break if ( !(in_math) && (math_index == ($latex[num[j]].length)) )
        if (in_math)
          math=math+math_letter
        end
        math_index+=1
        if (math_index == ($latex[num[j]].length) && (in_math))
          j+=1
          math_index = 0
        end
      end #end of math($) check
      i = j
    end
    eqn_starts = Array['\\\\begin\{equation\}', '\\\\begin\{eqnarray\}', '\\\[\[]']
    eqn_ends = Array['\\\\end\{equation\}',  '\\\\end\{eqnarray\}', '\\\[\]]']
    eqn_starts.each do |notation|
      if ($latex[num[i]].match(notation) )
        j = i
        temp = Array.new
        $out_tex.puts("\\begin{verbatim}Line: #{num[i]+1}* ")
        while (!$latex[num[j]].match(eqn_ends[eqn_starts.index(notation)]))
          temp.push($latex[num[j]])
          $out_tex.puts($latex[num[j]])
          j+=1
        end
        temp.push($latex[num[j]])
        $out_tex.puts($latex[num[j]])
        $out_tex.puts("\\end{verbatim}")
        temp_string = temp.to_s
        array_temp = Array[temp]
        @math[num[i]+1] = array_temp
        @math_dollar[num[i]+1] = array_temp
        $out_tex.puts(temp)
        i = j
      end
    end
      i+=1
    break if i>=num.length
  end
  check_sections(sections)
  check_subsections(subsections)
end

#Parser
def get_info(info_type, info_line)
#  beg = info_file[info_line].index(info_type)
  beg = $latex[info_line].index("{")
  temp = $latex[info_line][beg+1..-1]
#print "1) line=", info_file[info_line], " temp=", temp, "\n"
  j=info_line
  count_open = 1
  count_closed = 0
  temp1 = ''
  l = 0
  if temp.length == 0
    j+=1
    temp = temp+$latex[j]
  end
#print "2) temp=", temp, " open=", count_open, " closed= ", count_closed, "\n"
  while ((l < temp.length) && ((count_open != count_closed) || (count_open == 0)) )
    letter = temp[l,1]
    if letter.eql?("{")
      count_open+=1
    else letter.eql?("}")
      count_closed+=1
    end
    temp1 = temp1+letter
    temp1.sub!(/\n/, '')
    count_closed = temp1.count("}")
#print "3) length=", temp.length, " open=",count_open," closed=",
#count_closed," l=", l," temp1=", temp1, "\n"
    l+=1
    if ( (l == temp.length) && (count_open > count_closed) )
      j+=1
      temp = temp+$latex[j]
#print "4) length=", temp.length, "open=",count_open,"closed=",
#count_closed,"l=", l,"temp1=", temp1, "\n"
    end
  end
  l = 0
  count = 0
  new = ''
  if count_closed == 1
    line = temp.split(/\}/)
    new = line[0]
  else
print "#{count} closed: #{count_closed}\n"
    while (count < count_closed)
      letter = temp.substr(l,1)
      new = new+letter
      count = new.count("}")
      l+=1
    end
    new.chop
  end
  k=info_line+1
  new_return = new+"!!!"+k.to_s
  return new_return
end

def check_bibtex(bibtex)
  line = bibtex.split('!!!')
  $out_check.puts("Checking BibTeX Style\n")
    if line[0].match('plos2009')
      @bibtex= "BibTeX style OK!"
      $out_check.puts("\tBibTeX style OK!\n")
    else
      @bibtex= "Incorrect BibTex file #{line[9]} on line #{line[1]}."
      $out_check.puts("\tIncorrect BibTex file #{line[9]} on line #{line[1]}.\n")
    end
end
 
def check_header(in_lines)
  info = Array.new
  error = Array.new
  for i in 0..in_lines.length-1 do
    line = in_lines[i].split('!!!')
    info.push(line[0])
    error.push(line[1])
  end
#Approved Header Lines
  headers = {
    '\documentclass[10pt]{article}' => '1',
    '\topmargin 0.0cm' => '1',
    '\oddsidemargin 0.5cm' => '1',
    '\evensidemargin 0.5cm' => '1',
    '\textwidth 16cm' => '1',
    '\textheight 21cm' => '1',
    '\makeatletter' => '1',
    '\renewcommand{\@biblabel}[1]{\quad#1.}' => '1',
    '\makeatother' => '1',
    '\date{}' => '1',
    '\pagestyle{myheadings}' => '1',
    '\mark' => '1'
  }
  $out_check.puts("Checking Header Section")
  for i in 0..info.length-1 do
    line_num = error[i].to_i + 1
    if (!headers.has_key?(info[i].sub(/\s+$/,'')))
      @header="Error! Line #{line_num}: Header line * #{info[i]}* is not approved!<br>"
      $out_check.puts("\tError! Line #{line_num}: Header line *#{info[i]}* is not approved!\n")
    end 
  end
end

def check_packages(in_pack)
  info = Array.new
  error = Array.new
  @packages = Array.new
  for i in 0..in_pack.length-1 do
    line = in_pack[i].split('!!!')
    info.push(line[0])
    error.push(line[1])
  end
#Approved Packages
  packages = {
    'amsmath' => '1',
    'amssymb' => '1',
    'graphicx' => '1',
    'cite' => '1',
    'caption' => '1',
    'color' => '1',
  }
  count = 0
  $out_check.puts("Checking packages")
  for i in 0..info.length-1 do
    if (!packages.has_key?(info[i]))
      @packages.push("Error! Line #{error[i]}: Package *#{info[i]}* is not approved!")
      $out_check.puts("\tError! Line #{error[i]}: Package *#{info[i]}* is not approved!")
    elsif (packages.has_key?(info[i]))
      $out_tex.puts("\\usepackage{#{info[i]}}\n")
      packages.delete(info[i])
      count+=1
    end
  end
  if count==6
    @packages.push("Packages OK!")
    $out_check.puts("\tPackages OK!\n")
  elsif count < 6
    @packages.push("Error! Only #{count} of 6 required packages.  There are missing packages:")
    $out_check.puts("\tError! Only #{count} of 6 required packages.  There are missing packages:")
    packages.each do |key, value| 
      @packages.push("&nbsp;&nbsp;&nbsp; #{key}")
      $out_check.puts("\t#{key}\n")
    end
  end
end

def check_sections(secs)
  info = Array.new
  error = Array.new
  @sections = Hash.new
  #for i in 0..secs.length-1 do
  secs.each do |sec|
    line = sec.split('!!!')
    info.push(line[0])
    error.push(line[1])
  end
#Approved Sections
  sections = {
    'Abstract' => '1',
    'Author Summary' => '1',
    'Introduction' => '1',
    'Results' => '1',
    'Discussion' => '1',
    'Results/Discussion' => '1',
    'Methods' => '1',
    'Materials and Methods' => '1',
    'Models' => '1',
    'Model' => '1',
    'Acknowledgments' => '1',
    'References' => '1',
    'Figure Legends' => '1',
    'Tables' => '1'
  }
  $out_check.puts("Checking Sections\n")
  #for i in 0..info.length-1 do
  info.each do |section|
    if (!sections.has_key?(section))
      sec = "Section *#{section}* is not approved!"
      @sections[error[info.index(section)]] = sec
      $out_check.puts("\tError! Line #{error[info.index(section)]}: Section
*#{section}* is not approved!\n") 
      sect = Array.new
      sect.push(section)
    else
      sec = "Section *#{section}* is good!"
      @sections[error[info.index(section)]] = sec
      $out_check.puts("\tLine #{error[info.index(section)]}: Section: #{section}\n")
    end
  end
end

def check_subsections(secs)
  info = Array.new
  error = Array.new
  @subs = Hash.new
  $out_check.puts("Checking Subsections\n")
  secs.each do |subs|
    line = subs.split('!!!')
    @subs[line[1]] = line[0]
    $out_check.puts("\tLine #{line[1]}: Subsection: #{line[0]}\n")
  end
end

def check_banned_math(in_lines)
  lines = Array.new
  error = Array.new
  #banned = Array.new
  line = in_lines.split('!!!')
  number=line[1].to_i+1
  if line[0].match("\\\\boldsymbol[{]")
    temp = "Error: Cannot use \\boldsymbol for Math bold font!  Please use \\mathbf!  \n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match('^\^')
    temp = "Error: Must include the base of the superscript in the Math Environment!\n\tLine: #{number} *#{line[0]}*\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match('^_')
    temp = "Error: Must include the base of the subscript in the Math Environment!\n\tLine: #{number} *#{line[0]}*\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match("\\over[{]")
    temp = "Error: Cannot use \\over for fractions!  Please use \\frac{top}{botoom}!\n\tLine: #{number} #{line[0]}\n"
   $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match("\\\\bf[{]")
    temp = "Error: Cannot use \\bf for Math bold font!  Please use \\mathbf\n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp)
  elsif line[0].match("\\\\textsuperscript")
    temp = "Error: Cannot use \\textsuperscript for superscript!  Please use math mode and the '^' for superscript.\n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match("\\\\textrm[{]")
    temp = "Error: Cannot use \\textrm for roman text in the Math Environment.  Please use \\mathrm.\n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match("\\\\text[{]")
    temp = "Error: Cannot use \\text for roman text in the Math Environment.  Please use \\mathrm.\n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  elsif line[0].match("\\\\mbox[{]")
    temp = "Error: Cannot use \\mbox for roman tex in the Math Environment.  Please suse \\mathrm.\n\tLine: #{number} #{line[0]}\n"
    $out_check.puts(temp)
    @banned.push(temp.gsub!(/\n\t/, '<br>&nbsp;&nbsp;&nbsp;&nbsp;'))
  end
end  

##############################
get '/' do
  haml :index
end

post '/' do

  ROOT=Dir.pwd
  FileUtils.mv(params[:uploaded_data][:tempfile].path, "#{ROOT}/tmp/#{params[:uploaded_data][:filename]}")

  in_file=File.open("#{ROOT}/tmp/#{params[:uploaded_data][:filename]}", "r")

  file_path = ROOT+"/tmp/"+params[:uploaded_data][:filename]
  @file_name = params[:uploaded_data][:filename]

  #Create output TEX file
  $out_tex = File.new("#{file_path}.MATH.tex", "w+")
  #Create output Check file
  $out_check = File.new("#{file_path}.OUTPUT.txt", "w+")

#get '/' do
  
#  ROOT=Dir.pwd
#  @file_name="test.tex"
#  in_file=File.open(@file_name, "r")
#  $out_tex = File.new("#{ROOT}/tmp/test.tex.MATH.tex", "w+")
#  $out_check = File.new("#{ROOT}/tmp/test.tex.OUTPUT.txt", "w+")
  

  check_line_1 = "% Template for PLoS Computational Biology"
  check_line_2 = "% Version 1.0 January 2009"
  
  #Create new array, which hold the lines of the input LaTeX file
  $latex = Array.new
  header = Array.new
  body = Array.new
  math = Array.new
  @banned = Array.new
  
  #=begin
  #Initialize the array with the first two lines, which will be checked to see if
  #they were altered
  #=end
  $latex[0]=in_file.gets.sub!(/\n/, '')
  $latex[1]=in_file.gets.sub!(/\n/, '')
 
  $out_tex.puts("\\documentclass[10pt]{article}")
 
  $out_check.puts("Checking Template\n")
  if ( (!$latex[0].eql?(check_line_1)) || (!$latex[1].eql?(check_line_2)) )
    @template ="WARNING! Template may be altered!"
    $out_check.puts("\tWARNING! Template may be altered!\n")
  end
  
  #Read in file, line by line,
  while line=in_file.gets
    line.sub!(/\n/, '')
    $latex.push(line)
  end
  #Flag to detect \begin{document} 
  start=0
  #Iterate through file
  for i in 0..$latex.length-1 do
    line = i+1
    #Check for end of header 
    if $latex[i].match("\\\\begin[{]document[}]")
      start = 1
    end
    
    #Read in header lines
    if ( start == 0  )
      #temp = latex[i]+"!!!"+line.to_s
      header.push(i)
    elsif (start == 1)
      body.push(i)
    end
  end
  
  get_header(header)
  $out_tex.puts("\\begin{document}")
  get_body(body) 
  $out_tex.puts("\\end{document}")
  $out_tex.close
  $out_check.close
  in_file.close
  haml :output
end

get '/output' do
  output = params["output"]
  send_file("#{ROOT}/tmp/#{output}", :disposition => "attachment")
end

get '/math' do
  math = params["math"]
  send_file("#{ROOT}/tmp/#{math}", :disposition => "attachment")
end

helpers do
  def include_javascript(js)
    "/#{js}"
  end
end
