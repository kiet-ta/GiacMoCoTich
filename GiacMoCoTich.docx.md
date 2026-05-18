

**🌙  THẠCH SANH & LÝ THÔNG**

*Giấc Mơ Cổ Tích — Interactive Fairy Tale Game*

**GAME DESIGN DOCUMENT  (GDD)**

| Engine: Unity  |  Ngôn ngữ: C\# Thể loại: Visual Novel / Choice-Based Adventure Target: Người yêu truyện cổ tích Việt Nam Tone: Hồi hộp · Kỳ bí · Cảm xúc |
| :---: |

# **1\. TỔNG QUAN DỰ ÁN**

## **1.1 Concept Game**

Giấc Mơ Cổ Tích là một game nhập vai cảm xúc, nơi người chơi hóa thân vào cậu bé trong câu chuyện được gia đình kể mỗi đêm trước khi ngủ. Mỗi đêm là một giấc mơ — một cuộc phiêu lưu kỳ bí được tái hiện từ kho tàng truyện cổ tích Việt Nam, được tái dựng với bối cảnh và twist hoàn toàn mới.

Tập đầu tiên: Thạch Sanh & Lý Thông — Câu chuyện không chỉ đơn thuần về thiện và ác nữa. Trong giấc mơ này, mọi thứ đều mờ ám hơn, nguy hiểm hơn, và bí ẩn hơn. Lý Thông không chỉ là kẻ phản diện đơn giản — hắn có lý do của mình. Và Thạch Sanh — chính là bạn.

## **1.2 Thông Tin Dự Án**

| Tên game | Giấc Mơ Cổ Tích: Thạch Sanh & Lý Thông |
| :---- | :---- |
| **Engine** | Unity 2022 LTS trở lên |
| **Ngôn ngữ lập trình** | C\# |
| **Thể loại** | Visual Novel / Narrative Choice-Based Game |
| **Góc nhìn** | 2D — Side View \+ Close-up Character Portraits |
| **Platform mục tiêu** | PC (Windows/Mac), Mobile (iOS/Android) |
| **Target audience** | Trẻ em 8–14 tuổi & người lớn hoài niệm |
| **Tone** | Hồi hộp, kỳ bí, cảm xúc  |
| **Số chapter** | 5 Chapter chính \+ 1 Prologue \+ Epilogue |
| **Số ending** | 4 endings (True, Good, Bad, Secret) |

## **1.3 Concept Nền Tảng — 'Giấc Mơ'**

Khung game được đặt trong thế giới giấc mơ của cậu bé. Điều này cho phép:

* Tái dựng tự do cốt truyện gốc — vì đây là trí tưởng tượng của một đứa trẻ

* Thêm yếu tố kỳ bí, hồi hộp mà không phá vỡ logic truyện gốc

* Câu chuyện có thể thay đổi theo từng lần chơi — dream logic

* Cảm giác ấm áp khi bắt đầu và kết thúc mỗi chapter: hình ảnh cậu bé ngủ

# **2\. THIẾT KẾ CỐT TRUYỆN**

## **2.1 Cốt Truyện Gốc vs. Phiên Bản Reimagined**

Câu chuyện gốc Thạch Sanh & Lý Thông kể về chàng tiều phu nghèo bị người anh kết nghĩa phản bội nhiều lần, nhưng nhờ dũng cảm và tài năng, cuối cùng được minh oan và nên duyên với công chúa. Trong phiên bản Giấc Mơ Cổ Tích, chúng ta giữ nguyên tinh thần câu chuyện nhưng tái dựng bối cảnh, động lực nhân vật và thêm các yếu tố huyền bí mới.

| ⚠️  LƯU Ý THIẾT KẾ: 'Redefine' không có nghĩa là  thay đổi bài học đạo đức. Bài học 'ở hiền gặp lành, ác giả ác báo' vẫn là cốt lõi. |
| :---- |

## **2.2 Bối Cảnh Mới — 'Rừng Mộng'**

Thay vì bối cảnh làng quê bình thường, câu chuyện diễn ra tại Rừng Mộng — một khu rừng linh thiêng nơi ranh giới giữa thế giới người và thế giới thần linh rất mỏng manh. Về đêm, rừng biến đổi: cây cối thì thầm, ánh sáng ma trơi lập lòe, và những sinh vật không rõ danh tính xuất hiện.

### **2.2.1 Các Địa Điểm Chính**

| Căn Lều Thạch Sanh | Nơi bắt đầu. Ấm áp nhưng cô đơn. Ánh lửa bập bùng, tiếng gió rừng xa. |
| :---- | :---- |
| **Rừng Mộng — Ban Ngày** | Đẹp nhưng lạ. Màu sắc quá tươi. Cảm giác 'có gì đó không đúng'. |
| **Rừng Mộng — Ban Đêm** | Tối tăm, sương mù, âm thanh kỳ lạ. Đây là lúc nguy hiểm nhất. |
| **Hang Chằn Tinh** | Sâu trong lòng đất. Đá đen bóng phản chiếu ánh lửa. Mùi lưu huỳnh. |
| **Hang Đại Bàng** | Trên vách núi cheo leo, mây mù bao phủ. Gió hú như tiếng kêu cứu. |
| **Hoàng Cung** | Tráng lệ nhưng có bí mật. Không phải mọi thứ đều như vẻ ngoài. |
| **Ao Thần** | Nơi Thạch Sanh gặp Long Vương. Ánh sáng xanh huyền ảo dưới nước. |

## **2.3 Nhân Vật**

### **2.3.1 Thạch Sanh — Nhân Vật Người Chơi**

Thạch Sanh trong phiên bản này không chỉ là chàng tiều phu chất phác. Anh mang trong mình một bí mật: những đêm ngủ dưới gốc đa cổ thụ, anh nghe thấy tiếng thì thầm từ rừng. Anh không biết đây là năng lực hay là lời nguyền.

| Tuổi | \~18–20 (thanh niên) |
| :---- | :---- |
| **Ngoại hình** | Cao, rắn chắc, áo vải thô, lưng đeo rìu. Mắt thường có ánh sáng lạ khi nghe thấy 'rừng nói'. |
| **Tính cách** | Thật thà, dũng cảm, đôi khi ngây thơ — nhưng trực giác rất tốt |
| **Vũ khí** | Rìu gỗ (đầu game) → Cung Vàng (nhận từ Long Vương) → Đàn Thần |
| **Bí ẩn** | Con trai Thái tử trên thiên đình, bị đày xuống trần gian — nhưng ký ức bị phong ấn |
| **Voice** | Trầm, bình tĩnh. Lời thoại ngắn, đúng lúc. |

### **2.3.2 Lý Thông — Nhân Vật Phức Tạp**

Đây là điểm reimagine quan trọng nhất. Lý Thông không phải kẻ ác một chiều. Hắn là người anh kết nghĩa thực sự yêu quý Thạch Sanh — nhưng bị gia đình (mẹ và em gái) điều khiển, và bị lòng tham từng chút một ăn mòn. Người chơi sẽ thỉnh thoảng thấy 'Lý Thông tốt' trước khi hắn phản bội — điều này khiến sự phản bội đau hơn rất nhiều.

| Tính cách | Thông minh, hoạt ngôn, biết tính toán. Sâu trong lòng vẫn còn lương tâm. |
| :---- | :---- |
| **Động lực** | Muốn bảo vệ gia đình và giàu có — nhưng đi sai đường |
| **Arc** | Bắt đầu như người anh tốt → dần dần tha hóa → hối hận quá muộn |
| **Secret** | Biết bí mật về thân phận thật của Thạch Sanh nhưng chọn im lặng |

### **2.3.3 Công Chúa Quỳnh Nga**

Không chỉ là 'phần thưởng' cho Thạch Sanh. Công chúa là người thông minh, bị giam lỏng trong cung điện và tự mình tìm cách thoát. Cô đặt niềm tin vào Thạch Sanh sau khi cảm nhận được anh không nói dối.

### **2.3.4 Chằn Tinh — Kẻ Canh Giữ**

Không phải con quái vật thuần túy. Chằn Tinh là một vị thần bị đọa đày, bị phong ấn trong hang từ ngàn năm trước vì phạm lỗi với Ngọc Hoàng. Hắn điên loạn và đói khát — nhưng một phần trí nhớ vẫn còn. Người chơi có thể chọn cách đối phó với hắn: chiến đấu hoặc tìm hiểu.

# **3\. CHAPTER BREAKDOWN**

| 📖  Cấu trúc tổng thể: PROLOGUE → 5 CHAPTERS → EPILOGUE |
| :---- |

## **PROLOGUE — Đêm Kể Chuyện**

Bối cảnh: Phòng ngủ ấm áp. Bố / Mẹ ngồi bên giường cậu bé và bắt đầu kể câu chuyện Thạch Sanh. Giọng kể dần dần nhòa với tiếng gió, ánh đèn mờ dần, và cậu bé chìm vào giấc ngủ. Màn hình fade out, rồi fade in vào thế giới trong mơ.

Mục tiêu thiết kế: Tạo cảm giác ấm áp, hoài niệm, an toàn — trước khi câu chuyện trở nên hồi hộp.

## **CHAPTER 1 — Gốc Đa & Tiếng Thì Thầm**

*"Đêm nay rừng nói gì với mày, Thạch Sanh?"*

Bối cảnh: Thạch Sanh sống một mình dưới gốc đa. Lý Thông xuất hiện với vẻ thân thiện, mời Thạch Sanh về nhà, kết nghĩa anh em. Cùng đêm đó, Thạch Sanh nghe tiếng thì thầm từ rừng cảnh báo về một mối nguy không rõ ràng.

### **Lựa Chọn Chính — Chapter 1**

Khi Lý Thông mời kết nghĩa:

| Lựa chọn A Đồng ý ngay — 'Được thôi, có người bầu bạn cũng vui.' *→ Mở nhanh chuỗi sự kiện. Lý Thông tin tưởng hơn.* |  | Lựa chọn C Từ chối ban đầu — 'Tao quen sống một mình rồi.' *→ Chuỗi event khó hơn, nhưng phần thưởng lớn hơn ở cuối.* |
| :---- | :---- | :---- |
| **Lựa chọn B** **Do dự — 'Để tao nghĩ đã. Rừng vừa nhắc tao cẩn thận với người lạ.'** *→ Lý Thông tò mò về khả năng của Thạch Sanh. Unlock scene đặc biệt.* |  |  |

Sự Kiện Chính: Đêm đó, Chằn Tinh đòi mạng người — theo lệ cũ của làng. Lý Thông đẩy Thạch Sanh đi thế mạng đầu tiên bằng một lời dối trá nhẹ nhàng. Người chơi chứng kiến — và cảm thấy nghi ngờ.

## **CHAPTER 2 — Hang Của Bóng Tối**

*"Trong tối tăm nhất, mày sẽ thấy điều mà ánh sáng giấu đi."*

Bối cảnh: Thạch Sanh vào hang Chằn Tinh. Không phải chỉ là chiến đấu — đây là cuộc thẩm vấn tâm lý. Chằn Tinh hỏi Thạch Sanh: 'Mày có biết tại sao mày được chọn không?' Trong hang có những bức tranh khắc trên đá kể về quá khứ của Chằn Tinh và... một người giống Thạch Sanh.

### **Lựa Chọn Chính — Chapter 2**

| Lựa chọn A Chiến đấu ngay — không để lắng nghe *→ Thắng nhanh nhưng mất clue về thân phận. Bad path về lore.* |  | Lựa chọn C Thương lượng — tìm cách giải phóng Chằn Tinh *→ Kết cục bất ngờ: Chằn Tinh thành đồng minh tạm thời.* |
| :---- | :---- | :---- |
| **Lựa chọn B** **Lắng nghe trước khi chiến đấu** *→ Nhận được mảnh ký ức, mở Secret Ending path.* |  |  |

Kết thúc chapter: Thạch Sanh thắng, mang về đầu Chằn Tinh. Lý Thông chiếm công. Người chơi thấy phản ứng của Thạch Sanh — và lựa chọn cách phản ứng.

## **CHAPTER 3 — Đại Bàng & Vực Thẳm**

*"Ngã xuống vực không đáng sợ. Đáng sợ là không biết mình sẽ rơi bao lâu."*

Bối cảnh: Công chúa Quỳnh Nga bị Đại Bàng thần bắt cóc. Lý Thông lại đẩy Thạch Sanh vào nguy hiểm. Lần này, Thạch Sanh hiểu rõ hơn — nhưng vẫn chọn đi. Vì Thạch Sanh nghe rừng nói: có người cần được cứu.

Điểm đặc biệt của chapter này: Công chúa Quỳnh Nga không bị động. Khi Thạch Sanh tiếp cận hang Đại Bàng, cô đang tự mình tìm cách thoát. Họ gặp nhau và cùng lên kế hoạch — đây là lần đầu tiên Thạch Sanh nói chuyện thật sự với ai đó tin tưởng anh.

### **Lựa Chọn Chính — Chapter 3**

| Lựa chọn A Cứu công chúa rồi ra ngay *→ Nhanh, an toàn. Nhưng bỏ lỡ bí mật trong hang Đại Bàng.* |  | Lựa chọn C Tin tưởng kế hoạch của công chúa *→ Đại Bàng bị bẫy thay vì chiến đấu. Công chúa join party.* |
| :---- | :---- | :---- |
| **Lựa chọn B** **Ở lại khám phá hang thêm** *→ Tìm thấy cuốn sách cổ — chìa khóa của Secret Ending.* |  |  |

Twist: Lý Thông lấp cửa hang sau khi Thạch Sanh xuống. Người chơi bị kẹt dưới đáy vực — và câu chuyện thực sự bắt đầu.

## **CHAPTER 4 — Dưới Đáy Ao — Thế Giới Của Long Vương**

*"Dưới đáy nước, thế giới nhìn từ trên xuống trông như thế nào?"*

Bối cảnh: Thạch Sanh tìm đường thoát qua ao thần dưới vực, lạc vào thế giới Long Cung. Đây là chapter đẹp nhất và bí ẩn nhất. Long Vương không phải vị thần đơn thuần — ông biết thân phận thật của Thạch Sanh và đang chờ đợi anh từ lâu.

Tại đây Thạch Sanh nhận Đàn Thần và Cung Vàng. Nhưng Long Vương cũng thử thách anh: 'Con có thực sự muốn biết mình là ai không?' Đây là lựa chọn ảnh hưởng lớn nhất đến ending.

### **Lựa Chọn Quan Trọng Nhất — Chapter 4**

| Lựa chọn A Chấp nhận biết sự thật về thân phận *→ Unlock True Ending / Secret Ending path. Cảm xúc nhất.* |  | Lựa chọn C Hỏi ngược Long Vương — 'Tại sao ông lại chờ tôi?' *→ Mở ra subplot về Long Cung và lịch sử Rừng Mộng.* |
| :---- | :---- | :---- |
| **Lựa chọn B** **Từ chối — 'Tôi chỉ muốn trở về và sống bình thường'** *→ Good Ending path. Ấm áp nhưng không trọn vẹn.* |  |  |

## **CHAPTER 5 — Tiếng Đàn Phán Xét**

*"Khi đàn cất tiếng, kẻ có lỗi sẽ không thể che giấu được nữa."*

Bối cảnh: Thạch Sanh trở về. Đám cưới giả của Lý Thông và công chúa sắp diễn ra. Thạch Sanh ngồi trong ngục, chỉ có cây đàn thần. Tiếng đàn vang lên — và câu chuyện kết thúc không phải bằng thanh kiếm mà bằng âm nhạc và sự thật.

Đây là chapter cảm xúc nhất. Người chơi thấy Lý Thông đứng trước Thạch Sanh — và phải lựa chọn: tha thứ hay để công lý phán xét.

### **Lựa Chọn Cuối — Quyết Định Ending**

| Lựa chọn A Tha thứ cho Lý Thông — 'Mày đã khổ đủ rồi' *→ True Ending: Cảm xúc nhất, Lý Thông hối hận thật.* |  | Lựa chọn C Tiết lộ tất cả bí mật về Chằn Tinh và Long Cung *→ Secret Ending: Thạch Sanh trở về thiên đình.* |
| :---- | :---- | :---- |
| **Lựa chọn B** **Để vua phán xét — không can thiệp** *→ Good Ending: Công bằng, kết thúc truyền thống.* |  | **Lựa chọn D** **Trừng phạt Lý Thông bằng chính tay mình** *→ Bad Ending: Thạch Sanh thắng nhưng mất đi sự trong sáng.* |

# **4\. ENDING MATRIX**

Kết cục của game được quyết định bởi tổ hợp các lựa chọn trong toàn bộ 5 chapter, không chỉ chapter cuối. Dưới đây là bảng tóm tắt 4 ending chính:

| Ending | Tên | Điều Kiện Chính | Nội Dung Tóm Tắt |
| :---- | :---- | :---- | :---- |
| TRUE | Ánh Sáng Tha Thứ | Nghe Chằn Tinh \+ Tha thứ Lý Thông | Lý Thông hối cải. Thạch Sanh kết hôn, sống bình an. Rừng Mộng được thanh tẩy. Cảm xúc nhất. |
| GOOD | Công Lý Truyền Thống | Chiến đấu thẳng \+ Để vua phán xét | Kết thúc như truyện gốc. Lý Thông bị đày. Thạch Sanh hạnh phúc nhưng cảm giác thiếu thiếu. |
| SECRET | Con Trời Trở Về | Nhận sự thật từ Long Vương \+ Tiết lộ bí mật | Thạch Sanh biết thân phận, chọn trở về thiên đình sau khi hoàn thành sứ mệnh. Kết mở, thơ mộng. |
| BAD | Bóng Tối Bên Trong | Chọn trừng phạt Lý Thông tự tay | Thạch Sanh thắng nhưng mang nỗi đau. Rừng Mộng không được chữa lành. Kết buồn nhưng chân thực. |

# **5\. KIẾN TRÚC UNITY & C\#**

## **5.1 Tổng Quan Kiến Trúc**

Game được xây dựng theo mô hình kiến trúc phân lớp, phù hợp với dự án Visual Novel vừa và nhỏ trong Unity. Đây là kiến trúc khuyến nghị:

| 🏗️  LAYER ARCHITECTURE — 4 Tầng Chính |
| :---- |

| Tầng | Trách Nhiệm | Thành Phần / Script |
| :---- | :---- | :---- |
| **Presentation Layer** | Hiển thị UI, animation, âm thanh | DialogueUI.cs, ChoicePanel.cs, SceneTransition.cs, AudioManager.cs |
| **Game Logic Layer** | Điều phối story flow, xử lý lựa chọn | StoryManager.cs, ChoiceHandler.cs, CharacterController.cs, EndingCalculator.cs |
| **Data Layer** | Lưu trữ dữ liệu story, save/load game | StoryData.cs (ScriptableObject), SaveSystem.cs, PlayerProgress.cs |
| **Core / Utility Layer** | Hệ thống nền tảng dùng chung | GameManager.cs (Singleton), EventBus.cs, SceneLoader.cs |

## **5.2 Scene Structure**

Cấu trúc Scene trong Unity Project:

* BootScene — Khởi động game, load GameManager, kiểm tra save

* MainMenuScene — Menu chính, load save, settings

* PrologueScene — Cảnh kể chuyện, intro cậu bé

* Chapter\_01\_Scene → Chapter\_05\_Scene — Mỗi chapter là 1 scene

* EndingScene\_True / Good / Bad / Secret — 4 scene kết

* UIScene (Additive) — Load song song, chứa Dialogue UI, HUD

## **5.3 Data Flow — Dialogue & Choice System**

Luồng dữ liệu chính khi người chơi tiến qua một dialogue node:

1. StoryManager load StoryData (ScriptableObject) cho chapter hiện tại

2. DialogueNode được đọc theo thứ tự từ list nodes

3. Nếu node là dialogue thường: DialogueUI hiển thị text \+ portrait

4. Nếu node là choice node: ChoicePanel hiển thị các lựa chọn

5. Người chơi chọn → ChoiceHandler ghi nhận vào PlayerProgress

6. StoryManager nhảy đến node tiếp theo dựa trên choice ID

7. Sau mỗi chapter: EndingCalculator tính điểm để quyết định ending

## **5.4 ScriptableObject Data Design**

Toàn bộ nội dung story được lưu trong ScriptableObject (không hardcode trong script). Điều này cho phép team content có thể chỉnh sửa story mà không cần lập trình viên.

| StoryChapterData | Chứa list DialogueNode cho mỗi chapter |
| :---- | :---- |
| **DialogueNode** | Mỗi node: speakerName, dialogueText, portrait, choices\[\], nextNodeID |
| **ChoiceData** | Mỗi lựa chọn: choiceText, nextNodeID, scoreImpact\[\] |
| **CharacterData** | Tên, portrait sprites, voice audio clip |
| **EndingData** | Điều kiện trigger, ending scene, narration text |

## **5.5 Save System**

Sử dụng JSON serialization với PlayerPrefs backup. Lưu các thông tin:

* Chapter hiện tại và node ID

* Tất cả lựa chọn đã thực hiện (Dictionary\<string, int\>)

* Ending score variables (trust, courage, knowledge, mercy)

* Unlocked endings để hiển thị trong Gallery

# **6\. ĐỊNH HƯỚNG ÂM THANH & HÌNH ẢNH**

## **6.1 Art Style**

Phong cách hình ảnh được gọi là 'Ink Dream' — kết hợp tranh mực Đông Á truyền thống với hiệu ứng glowing ánh sáng huyền ảo.

* Background: Tranh 2D cẩn thận, màu sắc trầm với highlight huyền bí (xanh lam, vàng, tím)

* Character Portraits: Side-view, semi-realistic, biểu cảm rõ ràng

* Particle Effects: Đom đóm, sương mù, ánh sáng thần linh — luôn di chuyển nhẹ nhàng

* Text Box: Cuộn giấy cổ, mực đen trên nền vàng nhạt

* Transitions: Ink wash dissolve giữa các scene

## **6.2 Sound Design**

Âm thanh là công cụ tạo cảm giác hồi hộp, kỳ bí chủ lực của game.

| Prologue BGM | Nhạc ấm áp, tiếng đàn bầu nhẹ nhàng — cảm giác nhà, an toàn |
| :---- | :---- |
| **Rừng Mộng — Ngày** | Tiếng chim, gió lá, nhạc nền nhẹ — nhưng luôn có 1 note lạ xa xa |
| **Rừng Mộng — Đêm** | Ambient tối. Tiếng gió, tiếng bước chân không rõ nguồn. Không có nhạc. |
| **Hang Chằn Tinh** | Low drone, tiếng nhỏ giọt nước, hơi thở nặng nề |
| **Long Cung** | Nhạc dưới nước — ethereal, glass harp, tiếng sóng nhẹ |
| **Tiếng Đàn Thần** | Âm thanh thật của đàn tranh Việt Nam — moment cathartic nhất game |
| **Khi phản bội xảy ra** | Im lặng tuyệt đối rồi một tiếng drum thấp duy nhất |

## **6.3 UI/UX Direction**

* Font: Nôm-style font cho tên nhân vật, font sạch dễ đọc cho dialogue

* Choice buttons: Fade in từng cái một, không hiện đồng loạt

* Không có thanh HP hay bất kỳ game-ified element nào — đây là story-first

* Indicator: Khi lựa chọn ảnh hưởng đến ending, có hiệu ứng ánh sáng nhẹ trên button

# **7\. KẾ HOẠCH TRIỂN KHAI**

| 📅  Study & Development Plan — 8 Tuần |
| :---- |

| Tuần | Mục Tiêu | Công Việc Chi Tiết | Deliverable |
| :---- | :---- | :---- | :---- |
| **Tuần 1–2** | Foundation & Core Systems | Setup Unity project, GameManager singleton, EventBus, SceneLoader. Thiết kế ScriptableObject schema cho StoryData. | Core architecture chạy được |
| **Tuần 3** | Dialogue System | DialogueUI.cs, text typewriter effect, character portrait system, DialogueNode loading từ ScriptableObject. | Dialogue system demo |
| **Tuần 4** | Choice System & Branching | ChoicePanel.cs, ChoiceHandler.cs, branching logic, PlayerProgress tracking, EndingCalculator base. | Choice system demo với Prologue |
| **Tuần 5** | Save/Load & Scene Flow | SaveSystem với JSON, SceneTransition với ink wash effect, Chapter flow hoàn chỉnh. | Save/Load hoạt động |
| **Tuần 6** | Audio & Visual Polish | AudioManager (BGM/SFX layers), particle effects, UI animations, portrait expressions. | Chapter 1 hoàn chỉnh |
| **Tuần 7** | Content — Full Story | Nhập toàn bộ story content cho 5 chapters vào ScriptableObjects. Test branching paths. | All chapters playable |
| **Tuần 8** | Testing & QA | Test tất cả 4 ending paths, fix bugs, balance pacing, polish transitions, build release. | Build hoàn chỉnh |

## **7.1 Practical Exercises — Luyện Tập Theo Module**

Mỗi tuần đi kèm một bài tập thực hành nhỏ để kiểm tra hiểu biết:

8. Tuần 1: Vẽ sơ đồ kiến trúc 4-layer của game, liệt kê từng script vào đúng layer

9. Tuần 2: Tạo 1 ScriptableObject DialogueNode với 3 fields và load nó trong một scene trống

10. Tuần 3: Implement typewriter effect cho text display

11. Tuần 4: Build choice system đơn giản: 2 lựa chọn → 2 dialogue khác nhau

12. Tuần 5: Implement save/load state của chapter hiện tại bằng JSON

13. Tuần 6: Tạo fade transition giữa 2 scene

14. Tuần 7: Build mini-version của Chapter 1 đầy đủ: dialogue \+ 1 choice point

15. Tuần 8: Code review — đảm bảo không có spaghetti code, refactor nếu cần

# **8\. PHỤ LỤC — GHI CHÚ THIẾT KẾ**

## **8.1 Design Principles**

**Principle 1: Story \> Mechanics**

Mọi quyết định kỹ thuật đều phải phục vụ câu chuyện. Nếu một feature làm phức tạp narrative, bỏ feature đó.

**Principle 2: Lựa chọn có trọng lượng**

Không có lựa chọn nào là 'đúng rõ ràng' trong bối cảnh đưa ra. Người chơi phải suy nghĩ — và chịu trách nhiệm với lựa chọn của mình.

**Principle 3: Tôn trọng văn hóa gốc**

Dù 'redefine', bài học đạo đức và tinh thần nhân văn của truyện cổ tích Việt Nam phải được giữ gìn. Game là sự diễn giải, không phải sự chế giễu.

**Principle 4: Cảm xúc qua chi tiết nhỏ**

Tiếng Lý Thông do dự trước khi lấp cửa hang. Công chúa bỏ lại chiếc trâm cài tóc trong hang Đại Bàng. Những chi tiết nhỏ này tạo nên cảm xúc lớn.

## **8.2 Scope Control — Những Gì KHÔNG Làm**

Để tránh scope creep, tài liệu này xác định rõ những gì nằm ngoài phạm vi v1.0:

* Không có combat system phức tạp — tất cả 'chiến đấu' được xử lý qua dialogue choice

* Không có inventory system

* Không có voice acting trong bản demo

* Không có multiplayer hoặc online features

* Không có procedural content — tất cả story là handcrafted

## **8.3 Expansion Ideas — v2.0+**

Sau khi hoàn thiện Thạch Sanh, các tập tiếp theo của Giấc Mơ Cổ Tích có thể bao gồm:

* Tập 2: Tấm Cám — Reimagined với góc nhìn từ Cám

* Tập 3: Sơn Tinh Thủy Tinh — Câu chuyện về thiên tai và tình yêu

* Tập 4: Sự Tích Trầu Cau — Câu chuyện về tình anh em và sự hiểu lầm

* Shared Universe: Các nhân vật trong các tập giao nhau trong Rừng Mộng

*— Hết tài liệu GDD v1.0 —*  
**Giấc Mơ Cổ Tích: Thạch Sanh & Lý Thông**

