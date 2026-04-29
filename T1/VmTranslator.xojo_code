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
		// Project 08 behavior: each *program folder* (a folder that contains one or more .vm files)
		// is translated into a single .asm file named <FolderName>.asm.
		Var stack() As FolderItem
		stack.Add(root)

		While stack.LastIndex >= 0
			Var current As FolderItem = stack.Pop

			If current <> Nil And current.Exists And current.IsFolder Then
				Var vmFiles() As FolderItem = VmFilesInFolder(current)
				If vmFiles.Count > 0 Then
					TranslateVmFolder(current, vmFiles, compareKey)
					translatedCount = translatedCount + vmFiles.Count
					Print("[OK] " + current.Name + ".asm (" + vmFiles.Count.ToString + " vm file(s))")
				End If
			End If

			For Each item As FolderItem In current.Children
				If item.IsFolder Then
					stack.Add(item)
				End If
			Next
		Wend
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function VmFilesInFolder(folder As FolderItem) As FolderItem()
		Var result() As FolderItem
		If folder Is Nil Or Not folder.Exists Or Not folder.IsFolder Then
			Return result
		End If

		For Each item As FolderItem In folder.Children
			If item Is Nil Or item.IsFolder Then Continue For
			If item.Name.Right(3).Lowercase = ".vm" Then
				result.Add(item)
			End If
		Next

		// deterministic order (manual sort for broad Xojo compatibility)
		If result.Count > 1 Then
			For i As Integer = 0 To result.LastIndex - 1
				For j As Integer = i + 1 To result.LastIndex
					Var nameI As String = If(result(i) <> Nil, result(i).Name.Lowercase, "")
					Var nameJ As String = If(result(j) <> Nil, result(j).Name.Lowercase, "")
					If nameJ < nameI Then
						Var tmp As FolderItem = result(i)
						result(i) = result(j)
						result(j) = tmp
					End If
				Next
			Next
		End If
		Return result
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub TranslateVmFolder(programFolder As FolderItem, vmFiles() As FolderItem, ByRef compareKey As Int64)
		Var asmFile As FolderItem = programFolder.Child(programFolder.Name + ".asm")
		Var output As TextOutputStream = TextOutputStream.Create(asmFile)

		Var currentFunction As String = ""

		If FolderHasSysVm(vmFiles) Then
			WriteBootstrap(output, compareKey)
		End If

		For Each vmFile As FolderItem In vmFiles
			Var fileBaseName As String = vmFile.Name.Left(vmFile.Name.Length - 3) // without .vm
			Var input As TextInputStream = TextInputStream.Open(vmFile)

			While Not input.EndOfFile
				Var line As String = CleanLine(input.ReadLine)
				If line = "" Then Continue

				If WriteArithmetic(output, line, compareKey) Then
					Continue
				End If

				If WriteVmNonArithmetic(output, fileBaseName, line, compareKey, currentFunction) Then
					Continue
				End If
			Wend

			input.Close
		Next

		output.Close
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function FolderHasSysVm(vmFiles() As FolderItem) As Boolean
		For Each f As FolderItem In vmFiles
			If f <> Nil And f.Name = "Sys.vm" Then
				Return True
			End If
		Next
		Return False
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteBootstrap(out As TextOutputStream, ByRef compareKey As Int64)
		// SP=256
		out.WriteLine("@256")
		out.WriteLine("D=A")
		out.WriteLine("@SP")
		out.WriteLine("M=D")
		// call Sys.init 0
		WriteCall(out, "Sys.init", 0, compareKey)
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function Tokenize(line As String) As String()
		Var raw() As String = line.Split(" ")
		Var parts() As String
		For Each p As String In raw
			If p.Trim <> "" Then parts.Add(p.Trim)
		Next
		Return parts
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function WriteVmNonArithmetic(out As TextOutputStream, fileBaseName As String, line As String, ByRef compareKey As Int64, ByRef currentFunction As String) As Boolean
		Var parts() As String = Tokenize(line)
		If parts.Count = 0 Then Return True

		Select Case parts(0)
		Case "push", "pop"
			WritePushPop(out, fileBaseName, line)
			Return True

		Case "label"
			If parts.Count >= 2 Then
				WriteLabel(out, fileBaseName, currentFunction, parts(1))
			End If
			Return True

		Case "goto"
			If parts.Count >= 2 Then
				WriteGoto(out, fileBaseName, currentFunction, parts(1))
			End If
			Return True

		Case "if-goto"
			If parts.Count >= 2 Then
				WriteIfGoto(out, fileBaseName, currentFunction, parts(1))
			End If
			Return True

		Case "function"
			If parts.Count >= 3 Then
				Var functionName As String = parts(1)
				Var localCount As Integer = Val(parts(2))
				WriteFunction(out, functionName, localCount)
				currentFunction = functionName
			End If
			Return True

		Case "call"
			If parts.Count >= 3 Then
				Var functionName As String = parts(1)
				Var argCount As Integer = Val(parts(2))
				WriteCall(out, functionName, argCount, compareKey)
			End If
			Return True

		Case "return"
			WriteReturn(out)
			Return True
		End Select

		Return False
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Function ScopedLabel(fileBaseName As String, currentFunction As String, labelName As String) As String
		If currentFunction <> "" Then
			Return currentFunction + "$" + labelName
		End If
		Return fileBaseName + "$" + labelName
	End Function
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteLabel(out As TextOutputStream, fileBaseName As String, currentFunction As String, labelName As String)
		Var symbol As String = ScopedLabel(fileBaseName, currentFunction, labelName)
		out.WriteLine("(" + symbol + ")")
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteGoto(out As TextOutputStream, fileBaseName As String, currentFunction As String, labelName As String)
		Var symbol As String = ScopedLabel(fileBaseName, currentFunction, labelName)
		out.WriteLine("@" + symbol)
		out.WriteLine("0;JMP")
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteIfGoto(out As TextOutputStream, fileBaseName As String, currentFunction As String, labelName As String)
		Var symbol As String = ScopedLabel(fileBaseName, currentFunction, labelName)
		out.WriteLine("@SP")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@" + symbol)
		out.WriteLine("D;JNE")
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteFunction(out As TextOutputStream, functionName As String, localCount As Integer)
		out.WriteLine("(" + functionName + ")")
		For i As Integer = 1 To localCount
			out.WriteLine("@0")
			out.WriteLine("D=A")
			out.WriteLine("@SP")
			out.WriteLine("A=M")
			out.WriteLine("M=D")
			out.WriteLine("@SP")
			out.WriteLine("M=M+1")
		Next
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteCall(out As TextOutputStream, functionName As String, argCount As Integer, ByRef compareKey As Int64)
		compareKey = compareKey + 1
		Var id As String = Str(compareKey)
		Var returnLabel As String = "RET_ADDR." + id

		// push return-address
		out.WriteLine("@" + returnLabel)
		out.WriteLine("D=A")
		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")

		// push LCL
		out.WriteLine("@LCL")
		out.WriteLine("D=M")
		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")

		// push ARG
		out.WriteLine("@ARG")
		out.WriteLine("D=M")
		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")

		// push THIS
		out.WriteLine("@THIS")
		out.WriteLine("D=M")
		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")

		// push THAT
		out.WriteLine("@THAT")
		out.WriteLine("D=M")
		out.WriteLine("@SP")
		out.WriteLine("A=M")
		out.WriteLine("M=D")
		out.WriteLine("@SP")
		out.WriteLine("M=M+1")

		// ARG = SP - 5 - argCount
		out.WriteLine("@SP")
		out.WriteLine("D=M")
		out.WriteLine("@" + Str(argCount + 5))
		out.WriteLine("D=D-A")
		out.WriteLine("@ARG")
		out.WriteLine("M=D")

		// LCL = SP
		out.WriteLine("@SP")
		out.WriteLine("D=M")
		out.WriteLine("@LCL")
		out.WriteLine("M=D")

		// goto function
		out.WriteLine("@" + functionName)
		out.WriteLine("0;JMP")
		out.WriteLine("(" + returnLabel + ")")
	End Sub
	#tag EndMethod


	#tag Method, Flags = &h21
	Private Sub WriteReturn(out As TextOutputStream)
		// FRAME = LCL
		out.WriteLine("@LCL")
		out.WriteLine("D=M")
		out.WriteLine("@R13")
		out.WriteLine("M=D")

		// RET = *(FRAME-5)
		out.WriteLine("@5")
		out.WriteLine("A=D-A")
		out.WriteLine("D=M")
		out.WriteLine("@R14")
		out.WriteLine("M=D")

		// *ARG = pop()
		out.WriteLine("@SP")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@ARG")
		out.WriteLine("A=M")
		out.WriteLine("M=D")

		// SP = ARG + 1
		out.WriteLine("@ARG")
		out.WriteLine("D=M+1")
		out.WriteLine("@SP")
		out.WriteLine("M=D")

		// THAT = *(FRAME-1)
		out.WriteLine("@R13")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@THAT")
		out.WriteLine("M=D")

		// THIS = *(FRAME-2)
		out.WriteLine("@R13")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@THIS")
		out.WriteLine("M=D")

		// ARG = *(FRAME-3)
		out.WriteLine("@R13")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@ARG")
		out.WriteLine("M=D")

		// LCL = *(FRAME-4)
		out.WriteLine("@R13")
		out.WriteLine("AM=M-1")
		out.WriteLine("D=M")
		out.WriteLine("@LCL")
		out.WriteLine("M=D")

		// goto RET
		out.WriteLine("@R14")
		out.WriteLine("A=M")
		out.WriteLine("0;JMP")
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
		Var parts() As String = Tokenize(line)
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
