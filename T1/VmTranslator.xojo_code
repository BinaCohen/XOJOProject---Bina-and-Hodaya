#tag Module
' Authors: Bina Cohen: 207562901 & Hodaya Levinstein: 213803729

Public Module VmTranslator

	#tag Method, Flags = &h0
	Public Function RunInteractive() As Integer
		Stdout.Write("Folder to translate (e.g. MemoryAccess or StackArithmetic): ")
		Stdout.Flush

		Var folderName As String = Input.Trim
		If folderName = "" Then
			Print("[ERROR] No folder name was entered.")
			WaitForEnter("Press Enter to quit... ")
			Return 1
		End If

		Var root As FolderItem = FindRootFolder(folderName)
		If root Is Nil Then
			Print("[ERROR] Folder not found: " + folderName)
			Print("[INFO] Working dir: " + If(SpecialFolder.CurrentWorkingDirectory <> Nil, SpecialFolder.CurrentWorkingDirectory.NativePath, "<nil>"))
			Print("[INFO] Executable:  " + App.ExecutableFile.NativePath)
			WaitForEnter("Press Enter to quit... ")
			Return 1
		End If

		Print("[INFO] Scanning: " + root.NativePath)

		Var translatedCount As Integer = 0
		Var compareKey As Int64 = 0
		TranslateRecursively(root, translatedCount, compareKey)

		Print("[OK] Done. Translated " + translatedCount.ToString + " .vm file(s).")
		WaitForEnter("Press Enter to close... ")
		Return 0
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WaitForEnter(message As String)
		Stdout.Write(message)
		Stdout.Flush
		Var pause As String = Input
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function FindRootFolder(folderName As String) As FolderItem
		Var starts() As FolderItem
		starts.Add(SpecialFolder.CurrentWorkingDirectory)
		starts.Add(App.ExecutableFile.Parent)

		For Each start As FolderItem In starts
			Var p As FolderItem = start
			For i As Integer = 0 To 12
				If p Is Nil Then Exit
				Var test As FolderItem = p.Child(folderName)
				If test <> Nil And test.Exists And test.IsFolder Then
					Return test
				End If
				p = p.Parent
			Next
		Next

		Return Nil
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub TranslateRecursively(root As FolderItem, ByRef translatedCount As Integer, ByRef compareKey As Int64)
		Var stack() As FolderItem
		stack.Add(root)

		While stack.LastIndex >= 0
			Var current As FolderItem = stack.Pop

			For Each item As FolderItem In current.Children
				If item.IsFolder Then
					stack.Add(item)
					Continue For
				End If

				If item.Name.Right(3).Lowercase <> ".vm" Then
					Continue For
				End If

				TranslateVmFile(item, compareKey)
				translatedCount = translatedCount + 1
				Print("[OK] " + item.Name)
			Next
		Wend
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub TranslateVmFile(vmFile As FolderItem, ByRef compareKey As Int64)
		Var baseName As String = vmFile.Name.Left(vmFile.Name.Length - 3) // filename without the .vm suffix
		Var asmFile As FolderItem = vmFile.Parent.Child(baseName + ".asm")

		Var input As TextInputStream = TextInputStream.Open(vmFile)
		Var output As TextOutputStream = TextOutputStream.Create(asmFile)

		While Not input.EndOfFile
			Var line As String = CleanLine(input.ReadLine)
			If line = "" Then
				Continue
			End If

			If WriteArithmetic(output, line, compareKey) Then
				Continue
			End If

			WritePushPop(output, baseName, line)
		Wend

		output.Close
		input.Close
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function CleanLine(raw As String) As String
		Var line As String = raw
		Var commentPos As Integer = line.IndexOf("//")
		If commentPos >= 0 Then
			line = line.Left(commentPos)
		End If
		Return line.Trim
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function WriteArithmetic(out As TextOutputStream, op As String, ByRef compareKey As Int64) As Boolean
		Select Case op
		Case "add"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("A=A-1")
			out.WriteLine("M=D+M")
			Return True

		Case "sub"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("A=A-1")
			out.WriteLine("M=M-D")
			Return True

		Case "and"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("A=A-1")
			out.WriteLine("M=D&M")
			Return True

		Case "or"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("A=A-1")
			out.WriteLine("M=D|M")
			Return True

		Case "neg"
			out.WriteLine("@SP")
			out.WriteLine("A=M-1")
			out.WriteLine("M=-M")
			Return True

		Case "not"
			out.WriteLine("@SP")
			out.WriteLine("A=M-1")
			out.WriteLine("M=!M")
			Return True

		Case "eq", "gt", "lt"
			compareKey = compareKey + 1
			Var id As String = Str(compareKey)

			Var jump As String
			Select Case op
			Case "eq"
				jump = "JEQ"
			Case "gt"
				jump = "JGT"
			Case Else
				jump = "JLT"
			End Select

			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("A=A-1")
			out.WriteLine("D=M-D")
			out.WriteLine("@TRUE" + id)
			out.WriteLine("D;" + jump)
			out.WriteLine("@SP")
			out.WriteLine("A=M-1")
			out.WriteLine("M=0")
			out.WriteLine("@END" + id)
			out.WriteLine("0;JMP")
			out.WriteLine("(TRUE" + id + ")")
			out.WriteLine("@SP")
			out.WriteLine("A=M-1")
			out.WriteLine("M=-1")
			out.WriteLine("(END" + id + ")")
			Return True
		End Select

		Return False
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WritePushPop(out As TextOutputStream, fileBaseName As String, line As String)
		Var parts() As String = line.Split(" ")
		If parts.Count <> 3 Then Return

		Var cmd As String = parts(0)
		Var segment As String = parts(1)
		Var index As Integer = Val(parts(2))

		Select Case cmd
		Case "push"
			WritePush(out, fileBaseName, segment, index)
		Case "pop"
			WritePop(out, fileBaseName, segment, index)
		End Select
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WritePush(out As TextOutputStream, fileBaseName As String, segment As String, index As Integer)
		Select Case segment
		Case "constant"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")

		Case "local"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")
			out.WriteLine("@LCL")
			out.WriteLine("A=D+M")
			out.WriteLine("D=M")

		Case "argument"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")
			out.WriteLine("@ARG")
			out.WriteLine("A=D+M")
			out.WriteLine("D=M")

		Case "this"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")
			out.WriteLine("@THIS")
			out.WriteLine("A=D+M")
			out.WriteLine("D=M")

		Case "that"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")
			out.WriteLine("@THAT")
			out.WriteLine("A=D+M")
			out.WriteLine("D=M")

		Case "temp"
			out.WriteLine("@" + Str(index + 5))
			out.WriteLine("D=M")

		Case "pointer"
			If index = 0 Then
				out.WriteLine("@THIS")
			Else
				out.WriteLine("@THAT")
			End If
			out.WriteLine("D=M")

		Case "static"
			out.WriteLine("@" + fileBaseName + "." + Str(index))
			out.WriteLine("D=M")

		Else
			Return
		End Select

		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WritePop(out As TextOutputStream, fileBaseName As String, segment As String, index As Integer)
		Select Case segment
		Case "local", "argument", "this", "that"
			out.WriteLine("@" + Str(index))
			out.WriteLine("D=A")

			Select Case segment
			Case "local"
				out.WriteLine("@LCL")
			Case "argument"
				out.WriteLine("@ARG")
			Case "this"
				out.WriteLine("@THIS")
			Case Else
				out.WriteLine("@THAT")
			End Select

			out.WriteLine("D=D+M")
			out.WriteLine("@R13")
			out.WriteLine("M=D")
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("@R13")
			out.WriteLine("A=M")
			out.WriteLine("M=D")

		Case "temp"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("@" + Str(index + 5))
			out.WriteLine("M=D")

		Case "pointer"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			If index = 0 Then
				out.WriteLine("@THIS")
			Else
				out.WriteLine("@THAT")
			End If
			out.WriteLine("M=D")

		Case "static"
			out.WriteLine("@SP")
			out.WriteLine("AM=M-1")
			out.WriteLine("D=M")
			out.WriteLine("@" + fileBaseName + "." + Str(index))
			out.WriteLine("M=D")

		Else
			Return
		End Select
	End Sub
	#tag EndMethod


End Module
#tag EndModule
