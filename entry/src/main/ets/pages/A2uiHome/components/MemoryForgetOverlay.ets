export interface MemoryForgetOverlayCandidateView {
  candidateKey: string;
  fact: string;
  personaTag: string;
}

export const MEMORY_FORGET_OVERLAY_SELECTION_LIMIT: number = 5;

@Component
export struct MemoryForgetOverlay {
  @Prop visible: boolean = false;
  @Prop candidates: MemoryForgetOverlayCandidateView[] = [];
  @Prop selectedKeys: string[] = [];
  @Prop isWorking: boolean = false;
  onToggle: (candidateKey: string) => void = (_candidateKey: string): void => {};
  onCancel: () => void = (): void => {};
  onConfirm: () => void = (): void => {};

  private selected(candidateKey: string): boolean {
    return this.selectedKeys.indexOf(candidateKey) >= 0;
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick((): void => {
            if (!this.isWorking) this.onCancel();
          })

        Column() {
          Text('选择要忘记的长期记忆')
            .width('100%')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2B211C')
            .margin({ bottom: 8 })
          Text('删除后无法自动恢复，最多选择 5 条。')
            .width('100%')
            .fontSize(13)
            .fontColor('#76665D')
            .margin({ bottom: 14 })

          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.candidates, (candidate: MemoryForgetOverlayCandidateView) => {
                Row() {
                  Text(this.selected(candidate.candidateKey) ? '✓' : '')
                    .width(24)
                    .height(24)
                    .fontSize(16)
                    .fontColor('#FFFFFF')
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.selected(candidate.candidateKey) ? '#995F4C' : '#FFFFFF')
                    .border({ width: 1, color: '#C9B8AE' })
                    .borderRadius(7)
                  Column() {
                    Text(candidate.fact)
                      .width('100%')
                      .fontSize(15)
                      .fontColor('#332821')
                      .maxLines(3)
                    if (candidate.personaTag.length > 0) {
                      Text(candidate.personaTag)
                        .fontSize(11)
                        .fontColor('#8B7A70')
                        .margin({ top: 3 })
                    }
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#FFFDFC')
                .border({ width: 1, color: '#E8DDD6' })
                .borderRadius(14)
                .enabled(!this.isWorking && (this.selected(candidate.candidateKey) ||
                  this.selectedKeys.length < MEMORY_FORGET_OVERLAY_SELECTION_LIMIT))
                .onClick((): void => {
                  if (!this.isWorking) this.onToggle(candidate.candidateKey);
                })
              }, (candidate: MemoryForgetOverlayCandidateView): string => candidate.candidateKey)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 380 })

          Row({ space: 10 }) {
            Button('取消')
              .layoutWeight(1)
              .height(44)
              .enabled(!this.isWorking)
              .onClick((): void => this.onCancel())
            Button(this.isWorking ? '正在删除…' : '确认删除')
              .layoutWeight(1)
              .height(44)
              .enabled(!this.isWorking && this.selectedKeys.length > 0)
              .fontColor('#FFFFFF')
              .backgroundColor('#995F4C')
              .onClick((): void => this.onConfirm())
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 28 })
        .backgroundColor('#FFF8F3')
        .borderRadius({ topLeft: 24, topRight: 24 })
      }
      .width('100%')
      .height('100%')
      .zIndex(100)
    }
  }
}
