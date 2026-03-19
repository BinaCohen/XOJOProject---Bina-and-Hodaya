#tag Module
Begin Module T0VMWarmup
	#tag Property, Flags = &h21
		Private mOut As TextOutputStream
	#tag EndProperty
	
	#tag Property, Flags = &h21
		Private mCurrentVmBaseName As String
	#tag EndProperty
	
	#tag Property, Flags = &h21
		Private mLogicCounter As Integer
	#tag EndProperty
	
	#tag Method, Flags = &h0
		Sub RunInteractive()
			Stdout.Write("Enter input directory path: ")
			Var path As String = Stdin.ReadLine
			RunWithPath(path)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h0
		Sub RunWithPath(path As String)
			Var dir As FolderItem = GetFolderItem(path, FolderItem.PathTypeNative)
			
			If dir Is Nil Or Not dir.Exists Or Not dir.IsFolder Then
				Stdout.WriteLine("Invalid directory: " + path)
				Return
			End If
			
			Var outputFile As FolderItem = dir.Child(dir.Name + ".asm")
			
			mOut = TextOutputStream.Create(outputFile)
			
			For i As Integer = 1 To dir.Count
				Var item As FolderItem = dir.Item(i)
				If item Is Nil Then Continue
				If Not item.Exists Then Continue
				If item.IsFolder Then Continue
				
				If item.Extension.Lowercase = "vm" Then
					ProcessVmFile(item)
				End If
			Next
			
			mOut.Close
			mOut = Nil
			
			Stdout.WriteLine("Output file is ready: " + outputFile.Name)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub ProcessVmFile(vmFile As FolderItem)
			' Counter is per input file (logical commands only)
			mLogicCounter = 1
			
			' Store current VM file name WITHOUT extension (required by spec)
			mCurrentVmBaseName = BaseNameWithoutExtension(vmFile)
			
			Var input As TextInputStream = TextInputStream.Open(vmFile)
			
			While Not input.EndOfFile
				Var line As String = input.ReadLine
				line = CleanLine(line)
				If line = "" Then Continue
				
				Var tokens() As String = Tokenize(line)
				If tokens.Count = 0 Then Continue
				
				Var cmd As String = tokens(0).Lowercase
				
				Select Case cmd
				Case "add"
					HandleAdd
				Case "sub"
					HandleSub
				Case "neg"
					HandleNeg
				
				Case "eq"
					HandleEq
				Case "gt"
					HandleGt
				Case "lt"
					HandleLt
				
				Case "push"
					If tokens.Count >= 3 Then
						Var segment As String = tokens(1)
						Var index As Integer = CType(Val(tokens(2)), Integer)
						HandlePush(segment, index)
					End If
				
				Case "pop"
					If tokens.Count >= 3 Then
						Var segment As String = tokens(1)
						Var index As Integer = CType(Val(tokens(2)), Integer)
						HandlePop(segment, index)
					End If
				
				Else
					' Input is assumed valid per assignment; ignore unknown lines.
				End Select
			Wend
			
			input.Close
			
			Stdout.WriteLine("End of input file: " + vmFile.Name)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function CleanLine(line As String) As String
			' Strips optional inline comments and trims whitespace.
			Var s As String = line
			Var p As Integer = s.IndexOf("//")
			If p >= 0 Then
				s = s.Left(p)
			End If
			Return s.Trim
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function Tokenize(line As String) As String()
			Var normalized As String = line.ReplaceAll(Chr(9), " ")
			Var raw() As String = normalized.Split(" ")
			
			Var tokens() As String
			For Each part As String In raw
				Var t As String = part.Trim
				If t <> "" Then
					tokens.Add(t)
				End If
			Next
			
			Return tokens
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Function BaseNameWithoutExtension(f As FolderItem) As String
			Var name As String = f.Name
			
			If name.Length >= 3 Then
				Var lower As String = name.Lowercase
				If lower.EndsWith(".vm") Then
					Return name.Left(name.Length - 3)
				End If
			End If
			
			If f.Extension <> "" And name.Length > (f.Extension.Length + 1) Then
				Return name.Left(name.Length - (f.Extension.Length + 1))
			End If
			
			Return name
		End Function
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleAdd()
			mOut.WriteLine("command: add")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleSub()
			mOut.WriteLine("command: sub")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleNeg()
			mOut.WriteLine("command: neg")
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleEq()
			mOut.WriteLine("command: eq")
			mOut.WriteLine("counter: " + mLogicCounter.ToString)
			mLogicCounter = mLogicCounter + 1
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleGt()
			mOut.WriteLine("command: gt")
			mOut.WriteLine("counter: " + mLogicCounter.ToString)
			mLogicCounter = mLogicCounter + 1
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandleLt()
			mOut.WriteLine("command: lt")
			mOut.WriteLine("counter: " + mLogicCounter.ToString)
			mLogicCounter = mLogicCounter + 1
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandlePush(segment As String, index As Integer)
			mOut.WriteLine("command: push segment " + segment + " index " + index.ToString)
		End Sub
	#tag EndMethod
	
	#tag Method, Flags = &h21
		Private Sub HandlePop(segment As String, index As Integer)
			mOut.WriteLine("command: pop segment " + segment + " index " + index.ToString)
		End Sub
	#tag EndMethod
	
End Module
#tag EndModule
