import SwiftUI
import Security
import ParsecSDK

struct MainView:View
{
	var controller:ContentView?

	@State var refreshTime:String = "Last refreshed at 1/1/1970 12:00 AM"
	@State var hosts:Array<IdentifiableHostInfo> = []

	@State var showBaseAlert:Bool = false
	@State var baseAlertText:String = ""

	@State var showLogoutAlert:Bool = false

	@State var isConnecting:Bool = false
	@State var connectingToName:String = ""
	@State var pollTimer:Timer?

	@State var isRefreshing:Bool = false

	@State var inSettings:Bool = false

	var busy:Bool
	{
		isConnecting || isRefreshing || inSettings
	}

	init(_ controller:ContentView?)
	{
        self.controller = controller
        
        restoreAndMoveWithOldSession()
	}
    
    func restoreAndMoveWithOldSession(){
        if let data = loadFromKeychain(key: GLBDataModel.shared.SessionKeyChainKey) {
            let decoder = JSONDecoder()

            print("Retrieved data from Keychain: \(data).\nAnd restoring the session.")
            NetworkHandler.clinfo = try? decoder.decode(ClientInfo.self, from:data)
            print("Session restored and moved to the Main Page.")
        }
    }
    
    func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: kCFBooleanTrue!,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            print("Error loading from Keychain: \(status)")
            return nil
        }
        guard let data = item as? Data else {
            return nil
        }
        return data
    }

	var body:some View
	{
		ZStack()
		{
			// Background
			Rectangle()
				.fill(Color("BackgroundGray"))
				.edgesIgnoringSafeArea(.all)

			// Main controls
			VStack()
			{
				// Navigation controls
				ZStack()
				{
					Rectangle()
						.fill(Color("BackgroundGray"))
						.frame(height:52)
						.shadow(color:Color("Shading"), radius:4, y:6)
					HStack()
					{
						Button(action:{ showLogoutAlert = true }, label:{ Image(systemName:"chevron.left") })
							.padding()
							.alert(isPresented:$showLogoutAlert)
							{
								Alert(title:Text("Are you sure you want to logout?"), primaryButton:.destructive(Text("Logout"), action:logout), secondaryButton:.cancel(Text("Cancel")))
							}
						Spacer()
						Button(action:refreshList, label:{ Image(systemName:"arrow.clockwise") })
							.padding()
//						Button(action:{ withAnimation { inSettings = true } }, label:{ Image(systemName:"gear") })
//							.padding()
					}
					.foregroundColor(Color("AccentColor"))
				}
				.zIndex(1)

				ScrollView(.vertical)
				{
					VStack()
					{
						Text(refreshTime)
							.multilineTextAlignment(.center)
							.opacity(0.5)
						ForEach(hosts)
						{ i in
							VStack()
							{
								Image("IconTransparent")
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width:64, height:64)
									.background(Rectangle().fill(Color("BackgroundPrompt")))
									.cornerRadius(8)
								Text(i.hostname)
									.font(.system(size:20, weight:.medium))
									.multilineTextAlignment(.center)
								Text("\(i.user.name)#\(String(i.user.id))")
									.font(.system(size:16, weight:.medium))
									.multilineTextAlignment(.center)
									.opacity(0.5)
								Button(action:{ connectTo(i) })
								{
									ZStack()
									{
										Rectangle()
											.fill(Color("AccentColor"))
											.cornerRadius(8)
										Text("Connect")
											.foregroundColor(.white)
											.padding(8)
									}
									.frame(maxWidth:100)
								}
							}
							.padding()
							.frame(maxWidth:400)
							.background(Rectangle().fill(Color("BackgroundCard")))
							.cornerRadius(8)
						}
					}
					.padding()
				}
				.padding(.top, -8)
				.frame(maxWidth:.infinity)
				.alert(isPresented:$showBaseAlert)
				{
					Alert(title:Text(baseAlertText))
				}
			}
			.onAppear(perform:refreshList)
			.disabled(busy) // disable view if busy

			// Loading elements
			if isConnecting
			{
				ZStack()
				{
					Rectangle() // Darken background
						.fill(Color.black)
						.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack()
					{
						ActivityIndicator(isAnimating:$isConnecting, style:.large, tint:.white)
							.padding()
						Text("Requesting connection to \(connectingToName)...")
							.multilineTextAlignment(.center)
						Button(action:cancelConnection)
						{
							ZStack()
							{
								Rectangle()
									.fill(Color("BackgroundButton"))
									.cornerRadius(8)
								Text("Cancel")
									.foregroundColor(.red)
							}
						}
						.frame(maxWidth:100, maxHeight:48)
					}
					.padding()
					.background(Rectangle().fill(Color("BackgroundPrompt")))
					.cornerRadius(8)
					.padding()
				}
			}
			if isRefreshing
			{
				ZStack()
				{
					Rectangle() // Darken background
						.fill(Color.black)
						.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack()
					{
						ActivityIndicator(isAnimating:$isRefreshing, style:.large, tint:.white)
							.padding()
						Text("Refreshing hosts...")
							.multilineTextAlignment(.center)
					}
					.padding()
					.background(Rectangle().fill(Color("BackgroundPrompt")))
					.cornerRadius(8)
					.padding()
				}
			}

			// Settings screen
			if inSettings
			{
				ZStack()
				{
					Rectangle() // Darken background
						.fill(Color.black)
						.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack()
					{
						HStack()
						{
							Button(action:{ withAnimation { inSettings = false } }, label:{ Image(systemName:"xmark") })
							Spacer()
						}
						.foregroundColor(Color("AccentColor"))
						ScrollView(.vertical)
						{

						}
					}
					.padding()
					.background(Rectangle().fill(Color("BackgroundGray")))
					.cornerRadius(8)
					.padding()
				}
			}
		}
		.foregroundColor(Color("Foreground"))
	}

	func refreshList()
	{
		withAnimation
		{
			isRefreshing = true

			let clinfo = NetworkHandler.clinfo
			if clinfo == nil
			{
				isRefreshing = false;
				baseAlertText = "Error gathering hosts: Invalid session"
				showBaseAlert = true
				return
			}

			let apiURL = URL(string:"https://kessel-api.parsecgaming.com/v2/hosts?mode=desktop&public=false")!

			var request = URLRequest(url:apiURL)
			request.httpMethod = "GET";
			request.setValue("application/json", forHTTPHeaderField:"Content-Type")
			request.setValue("Bearer \(clinfo!.session_id)", forHTTPHeaderField:"Authorization")

			let task = URLSession.shared.dataTask(with:request)
			{ (data, response, error) in
				if let data = data
				{
					let statusCode:Int = (response as! HTTPURLResponse).statusCode
					let decoder = JSONDecoder()

					print(statusCode)
					print(String(data:data, encoding:.utf8)!)

					if statusCode == 200 // 200 OK
					{
						let info:HostInfoList =  try! decoder.decode(HostInfoList.self, from:data)
						hosts.removeAll()
						if let datas = info.data
						{
                            datas.forEach { h in
                                hosts.append(IdentifiableHostInfo(id:h.peer_id, hostname:h.name, user:h.user))
                            }
						}

						let formatter = DateFormatter()
						formatter.dateFormat = "M/d/yyyy h:mm a"
						refreshTime = "Last refreshed at \(formatter.string(from:Date()))"
					}
					else if statusCode == 403 // 403 Forbidden
					{
						let info:ErrorInfo = try! decoder.decode(ErrorInfo.self, from:data)

						baseAlertText = "Error gathering hosts: \(info.error)"
						showBaseAlert = true
					}
				}

				isRefreshing = false
			}
			task.resume()
		}
	}

	func connectTo(_ who:IdentifiableHostInfo)
	{
		connectingToName = who.hostname
		withAnimation { isConnecting = true }

		var status = CParsec.connect(who.id)

		// Polling status
		pollTimer = Timer.scheduledTimer(withTimeInterval:1, repeats:true)
		{ timer in
			status = CParsec.getStatus()

			if status == PARSEC_CONNECTING { return } // wait

			withAnimation { isConnecting = false }

			if status == PARSEC_OK
			{
				if let c = controller
				{
					c.setView(.parsec)
				}
			}
			else
			{
				baseAlertText = "Error connecting to host (code \(status.rawValue))"
				showBaseAlert = true
			}

			timer.invalidate()
		}
	}

	func cancelConnection()
	{
		withAnimation { isConnecting = false }

		CParsec.disconnect()

		pollTimer!.invalidate()
	}

	func logout()
	{
		NetworkHandler.clinfo = nil
		if let c = controller
		{
			c.setView(.login)
		}
	}
}

struct MainView_Previews:PreviewProvider
{
	static var previews:some View
	{
		MainView(nil)
	}
}

struct IdentifiableHostInfo:Identifiable
{
	var id:String // Peer ID
	var hostname:String
	var user:UserInfo
}
