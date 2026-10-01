# Myanmar Font Fix Collection

## အသုံးပြုနည်း

- Desktop ပေါ်က **Run-Repair-Font** ကိုဖွင့်ပါ။
- **I**: App အသစ် ၁၄ ခုအတွက် Pyidaungsu shortcut ထည့်/ပြန်ပြင်ရန်။ App မပိတ်ပါ။
- **1–14**: သက်ဆိုင်သာ app ကို Pyidaungsu နဲ့ ဖွင့်ရန်။ အရင်ဖွင့်ထားလျှင် save လုပ်ပြီး tray မှ Exit လုပ်ထားရပါမယ်။
- **T**: CMD/PowerShell အတွက် Myanmar Windows Terminal profile နှစ်ခုထည့်ရန်။
- **L**: အရင်ကရှိပြီးသား app များ၏ legacy repair menu။ အချို့ option က app ပိတ်တတ်လို့ အလုပ်အရင်သိမ်းပါ။
- **D**: OpenCode / Desktop Commander font + tray repair အဟောင်း။
- **W**: Qwen Pyidaungsu launcher အဟောင်း။
- **S**: နောက်ဆုံး font စစ်ထားတဲ့ရလဒ်။ လက်ရှိ app ဖွင့်နေကြောင်း သက်သေမဟုတ်ပါ။

Menu အားလုံးကို `↑/↓` နဲ့ရွေးပြီး `Enter` နှိပ်နိုင်သလို မူလ နံပါတ်/အက္ခရာ + `Enter` နည်းလည်း ဆက်သုံးနိုင်ပါတယ်။ ရွေးထားတဲ့လိုင်းကို အဝါရောင်နဲ့ပြပါတယ်။ Main menu မှာ `Esc` က Quit ဖြစ်ပြီး Legacy/Manual submenu မှာ `Esc` က Back ဖြစ်ပါတယ်။ Action ပြီးရင် လက်ရှိ menu ကိုပြန်ရောက်ပြီး `Q` နဲ့ collection တစ်ခုလုံးထွက်နိုင်ပါတယ်။ Legacy Manual ထဲက `A` သည် app အားလုံး patch လုပ်ပြီး `M` သည် `1,3,8` ပုံစံနဲ့ app အများကြီးရွေးနိုင်ပါတယ်။

App အသစ်များ: Freebuff, AutoClaw, Genspark Claw, Factory, Hermes Desktop, LM Studio, OpenWorker, AnythingLLM, Kimi, Qoder, MDHero, Notesnook, MarkText, WorkBuddyAI.

**WorkBuddyAI (v5.6.2)** က သူ့ main bundle ထဲမှာ သူ့ဘာသာသူ ဖန်တီးထားတဲ့ debug hook တစ်ခုပါရှိပါတယ် — `WORKBUDDY_REMOTE_DEBUGGING_PORT` environment variable ကို port နံပါတ်ဆက်ပြီး ထားရင် app က သူ့ဘာသာ `--remote-debugging-port` နဲ့ `--remote-allow-origins` ကို ကိုယ်ထဲ ထည့်ပေးပါတယ်။ `env-port` engine က ဒီ hook ကိုပဲ အသုံးပြုတာမို့ vendor file၊ CLI flag၊ policy ဘာမှ မထိရပါဘူး။ app update လုပ်လို့ ပြင်ဆင်မှု မပျက်ပါဘူး။ Legacy menu (အခန်း 12) ကလည်း WorkBuddyAI ကို ဒီ hook နဲ့ပဲ ပိတ်ပြီး ပြန်ဖွင့်ပေးနိုင်ပါတယ်။

Notesnook desktop က renderer အဖြစ် `https://app.notesnook.com` ကိုတင် ဖွင့်တဲ့ Electron shell ဖြစ်လို့ ဒီ origin တစ်ခုတည်းကို allowlist ထည့်ထားပါတယ်။ သူ့ UI က Inter ကို သုံးထားတဲ့အတွက် shared `font.css` အစား `font-notesnook.css` သီးသန့်သုံးပါတယ် — မြန်မာ codepoint (U+1000–109F စသည်) နေရာမှာသာ local Unicode font ပြောင်းပြီး Latin၊ KaTeX သင်္ချာနဲ့ icon font တွေက app မူလအတိုင်း ကျန်ပါတယ်။

## Update ပြီးရင်

အသစ်ထည့်ထားတဲ့ app တွေက `(Pyidaungsu)` shortcut နဲ့ ဖွင့်ရုံပါ။ မူလ app ဖိုင်တွေကို မပြင်ထားလို့ update ပြီး archive ထပ် patch လုပ်စရာ မလိုတဲ့ပုံစံဖြစ်ပါတယ်။ သတ်မှတ်ထားတဲ့ local debug port ကို update/crash အပြီး process အဟောင်းက ခဏယူထားရင် launcher က မမှားချိတ်ဘဲ free loopback port ကို auto ရွေးပြီး၊ shortcut ထပ်နှိပ်တဲ့အခါ exact app owner စစ်ပြီးမှ ပြန်ချိတ်ပါတယ်။ သို့သော် vendor က executable path/debugging support ပြောင်းသွားရင် launcher ပြန်ပြင်ဖို့ လိုနိုင်ပါတယ်။ ပုံမှန် vendor shortcut နဲ့ဖွင့်ရင် font helper မပါပါဘူး။

Font helper က hidden နဲ့ run ပါတယ်။ App renderer မရှိတော့ရင် ၆၀ စက္ကန့်အတွင်း ရပ်ပါမယ်။ Startup task အသစ် မထည့်ထားပါဘူး။

MDHero ကို `.md` default အဖြစ်ရွေးထားလျှင် `.md` file ကို double-click ဖွင့်တာလည်း Pyidaungsu launcher ကဖြတ်ပြီးဖွင့်ပါမယ်။ Windows ရဲ့ valid MDHero default ကိုမဖျက်ဘဲ သူ့ open command တစ်ခုတည်းကိုပြောင်းတာပါ။ အရင် command ကို `%LOCALAPPDATA%\Myanmar-Font-Fix\association-backups\md-progid-before-pyidaungsu.reg` မှာ rollback အတွက်သိမ်းထားပါတယ်။

## GitHub မှ အသုံးပြုရန်

Repo ကို မိမိနှစ်သက်ရာ writable folder ထဲ clone လုပ်ပြီး `npm install` လုပ်ပါ။ ပြီးလျှင် `Run-Repair-Font.bat` ကို ဖွင့်နိုင်ပါတယ်။ Pyidaungsu font ဖိုင်ကို ဒီ repo ထဲ မဖြန့်ဝေပါ။ ယုံကြည်ရတဲ့ source ကနေ သီးခြား install လုပ်ထားရပါမယ်။

## ဖိုင်နေရာ

- Project အပြည့်အစုံ: `C:\SK_AI\projects\Myanmar-Font-Fix`
- အလွယ်ခေါ်ရန်: `C:\SK_AI\scripts\Run-Myanmar-Font-Fix.bat`
- Local backup/result: `%LOCALAPPDATA%\Myanmar-Font-Fix`
- Collection အဟောင်းကို မဖျက်ထားပါ။ အဟောင်း repair entry point က အသစ်ဆီ ညွှန်ထားပါတယ်။

## ကန့်သတ်ချက်

CLI မှာ UTF-8 မှန်တာနဲ့ glyph ပုံဖော်မှု မှန်တာ မတူပါဘူး။ Pyidaungsu က proportional font ဖြစ်လို့ CLI table/cursor spacing အချို့ မညီနိုင်ပါသေးတယ်။ Codex CLI နဲ့ အခြား CLI အားလုံးကို စာပုံဖော်မှုအပြည့်အဝ အာမမခံပါဘူး။

OpenWorker နဲ့ MDHero လို WebView2 app များအတွက် executable-specific policy သာသတ်မှတ်ပါတယ်။ Browser/အခြား app တွေကို wildcard policy မသတ်မှတ်ပါဘူး။

Runtime backup၊ local status report၊ vendor dependency နဲ့ font binary တွေကို GitHub repo ထဲ မတင်ပါ။ Legacy repair အချို့က app ပိတ်ခြင်း၊ installed resource ပြင်ခြင်းနဲ့ Administrator permission လိုခြင်းရှိလို့ menu warning ကို ဖတ်ပြီးမှ run ပါ။ အသေးစိတ်နှင့် rollback ကို `README.md` မှာဖတ်နိုင်ပါတယ်။
