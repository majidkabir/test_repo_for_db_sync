SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: [rdt_830ExtUpd01]                                   */
/*                                                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode for PMI case                                         */
/*                                                                      */
/* Date        Author   Ver.  Purposes                                  */
/* 2024-10-29  PXL009   1.0   FCR-759 ID and UCC Length Issue           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_830ExtUpd01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cSuggLOC      NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cUserDefine01 NVARCHAR(30),
   @nTaskQTY      INT,
   @nQTY          INT,
   @cToLOC        NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   IF @nFunc = 830
   BEGIN
      IF @nStep = 4 -- QTY screen
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1 FROM [dbo].[ID] WHERE [Id] = @cDropID)
            BEGIN
               UPDATE [dbo].[ID] SET [UserDefine01] = ISNULL(@cUserDefine01, N'') WHERE [Id] = @cDropID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226751
                  SET @cErrMsg = [rdt].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP') --'UpdUDF01Fail'
                  GOTO Quit
               END
            END
         END
      END

      IF @nStep = 5 -- TO LOC screen
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1 FROM [dbo].[ID] WHERE [Id] = @cDropID)
            BEGIN
               UPDATE [dbo].[ID] SET [UserDefine01] = ISNULL(@cUserDefine01, N'') WHERE [Id] = @cDropID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226752
                  SET @cErrMsg = [rdt].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP') --'UpdUDF01Fail'
                  GOTO Quit
               END
            END
         END
      END

      IF @nStep = 7  -- Confirm Short Pick?
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS(SELECT 1 FROM [dbo].[ID] WHERE [Id] = @cDropID)
            BEGIN
               UPDATE [dbo].[ID] SET [UserDefine01] = ISNULL(@cUserDefine01, N'') WHERE [Id] = @cDropID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 226753
                  SET @cErrMsg = [rdt].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP') --'UpdUDF01Fail'
                  GOTO Quit
               END
            END
         END
      END

   END
Quit:

END

GO