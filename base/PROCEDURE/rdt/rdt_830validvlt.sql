SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_830ValidVLT]                                   */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: Checks that DROP ID provided can be used                    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-03-21 1.0  PPA374                                               */
/************************************************************************/

CREATE   PROC [RDT].[rdt_830ValidVLT] (
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10),  
   @cSuggLOC NVARCHAR( 10), 
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
      IF @nStep = 2 
      BEGIN
         IF (SELECT TOP 1 isnull(I_Field05,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) <> ''
         BEGIN
            UPDATE rdt.RDTMOBREC
            SET C_String30 = I_Field05
            WHERE Mobile = @nMobile
         END

         IF rtrim(ltrim(@cDropID)) = ''
         BEGIN
            SET @nErrNo = 217931
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNeeded
         END
         ELSE IF CHARINDEX(' ',@cdropid)>0 OR LEN(@cDropID)<>18 OR convert(nvarchar(30),substring(@cDropID,1,3)) <> '050'
         BEGIN
            SET @nErrNo = 217932
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFormat
         END
         ELSE IF (@cDropID IN (SELECT dropid FROM PICKDETAIL (NOLOCK) WHERE STORERKEY = 'HUSQ' AND STATUS <> '9' AND isnull(dropid,'') <> '')
            AND NOT EXISTS (SELECT 1 FROM pickdetail (NOLOCK) WHERE orderkey = (SELECT TOP 1 OrderKey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo) AND dropid = @cDropID)
            )OR @cDropID IN (SELECT dropid FROM packdetail (NOLOCK) WHERE STORERKEY = 'HUSQ' AND isnull(dropid,'') <> '')
            OR @cDropID IN (SELECT dropid FROM dropid (NOLOCK) WHERE isnull(dropid,'') <> '')
         BEGIN
            SET @nErrNo = 217933
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDISUsed
         END
         ELSE IF EXISTS (SELECT ID FROM PICKDETAIL (NOLOCK) WHERE STORERKEY = 'HUSQ' AND STATUS <> '9' AND dropid = @cDropID AND ((SELECT TOP 1 locationtype FROM loc (NOLOCK) WHERE loc = @cLOC) NOT IN ('PICK','CASE') OR (SELECT TOP 1 ID FROM pickdetail (NOLOCK) WHERE STORERKEY = 'HUSQ' AND STATUS <> '9' AND Dropid = @cDropID)<>''))
         BEGIN
            SET @nErrNo = 217934
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDUsedforPAL
         END
         ELSE IF isnull(@cPickZone,'') = '' AND (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
         BEGIN
            SET @nErrNo = 217935
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKzoneNeeded
         END
         ELSE IF NOT EXISTS (SELECT 1 FROM loc (NOLOCK) WHERE PickZone = case when @cPickZone = '' then  
         (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) else @cPickZone end
         AND loc = @cLOC)
         BEGIN
            SET @nErrNo = 217936
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotInPkZone
         END
      END
   END
END

GO