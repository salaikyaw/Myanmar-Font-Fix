# Myanmar Font Fix Collection

## အသုံးပြုနည်း

- Desktop ပေါ်က **Run-Repair-Font** ကိုဖွင့်ပါ။
- **I**: App အသစ် ၁၁ ခုအတွက် Pyidaungsu shortcut ထည့်/ပြန်ပြင်ရန်။ App မပိတ်ပါ။
- **1–11**: သက်ဆိုင်ရာ app ကို Pyidaungsu နဲ့ ဖွင့်ရန်။ အရင်ဖွင့်ထားလျှင် save လုပ်ပြီး tray မှ Exit လုပ်ထားရပါမယ်။
- **T**: CMD/PowerShell အတွက် Myanmar Windows Terminal profile နှစ်ခုထည့်ရန်။
- **L**: အရင်ကရှိပြီးသား app များ၏ legacy repair menu။ အချို့ option က app ပိတ်တတ်လို့ အလုပ်အရင်သိမ်းပါ။
- **D**: OpenCode / Desktop Commander font + tray repair အဟောင်း။
- **W**: Qwen Pyidaungsu launcher အဟောင်း။
- **S**: နောက်ဆုံး font စစ်ထားတဲ့ရလဒ်။ လက်ရှိ app ဖွင့်နေကြောင်း သက်သေမဟုတ်ပါ။

Menu အားလုံးကို `↑/↓` နဲ့ရွေးပြီး `Enter` နှိပ်နိုင်သလို မူလ နံပါတ်/အက္ခရာ + `Enter` နည်းလည်း ဆက်သုံးနိုင်ပါတယ်။ ရွေးထားတဲ့လိုင်းကို အဝါရောင်နဲ့ပြပါတယ်။ Main menu မှာ `Esc` က Quit ဖြစ်ပြီး Legacy/Manual submenu မှာ `Esc` က Back ဖြစ်ပါတယ်။ Action ပြီးရင် လက်ရှိ menu ကိုပြန်ရောက်ပြီး `Q` နဲ့ collection တစ်ခုလုံးထွက်နိုင်ပါတယ်။ Legacy Manual ထဲက `A` သည် app အားလုံး patch လုပ်ပြီး `M` သည် `1,3,8` ပုံစံနဲ့ app အများကြီးရွေးနိုင်ပါတယ်။

App အသစ်များ: Freebuff, AutoClaw, Genspark Claw, Factory, Hermes Desktop, LM Studio, OpenWorker, AnythingLLM, Kimi, Qoder, MDHero.

## Update ပြီးရင်

အသစ်ထည့်ထားတဲ့ app တွေက `(Pyidaungsu)` shortcut နဲ့ ဖွင့်ရုံပါ။ မူလ app ဖိုင်တွေကို မပြင်ထားလို့ update ပြီး archive ထပ် patch လုပ်စရာ မလိုတဲ့ပုံစံဖြစ်ပါတယ်။ သတ်မှတ်ထားတဲ့ local debug port ကို update/crash အပြီး process အဟောင်းက ခဏယူထားရင် launcher က မမှားချိတ်ဘဲ free loopback port ကို auto ရွေးပြီး၊ shortcut ထပ်နှိပ်တဲ့အခါ exact app owner စစ်ပြီးမှ ပြန်ချိတ်ပါတယ်။ သို့သော် vendor က executable path/debugging support ပြောင်းသွားရင် launcher ပြန်ပြင်ဖို့ လိုနိုင်ပါတယ်။ ပုံမှန် vendor shortcut နဲ့ဖွင့်ရင် font helper မပါပါဘူး။

Font helper က hidden နဲ့ run ပါတယ်။ App renderer မရှိတော့ရင် ၆၀ စက္ကန့်အတွင်း ရပ်ပါမယ်။ Startup task အသစ် မထည့်ထားပါဘူး။

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
