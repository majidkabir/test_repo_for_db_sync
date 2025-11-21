SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_830ExtValVLT]                                  */
/* Copyright: Maersk                                                    */
/*                                                                      */
/*                                                                      */
/* Date         Rev   Author   Purposes                                 */
/* 21/03/2024   1.0   PPA374   Checks that DROP ID provided can be used	*/
/* 08/08/2024   1.1   PPA374   Amended as per review comments           */
/* 28/01/2025   1.2   PPA374   Restricting usage to certain users        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_830ExtValVLT] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
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

   DECLARE @LocationType NVARCHAR(20)
   select top 1 @LocationType = LocationType from LOC (NOLOCK) where facility = @cFacility and loc = @cLOC

   IF @nFunc = 830
   BEGIN
      IF @nStep = 2 and @nInputKey = 1
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
            
         ELSE IF (exists(SELECT dropid FROM PICKDETAIL (NOLOCK) WHERE STORERKEY = @cStorerKey AND STATUS <> '9' AND DropID = @cDropID)
            AND NOT EXISTS (SELECT 1 FROM pickdetail (NOLOCK) WHERE Storerkey = @cStorerKey 
         AND orderkey = (SELECT TOP 1 OrderKey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo) AND dropid = @cDropID)
            )OR exists(select 1 from PackDetail (NOLOCK) where STORERKEY = @cStorerKey AND Dropid = @cDropID)
            OR exists(SELECT dropid FROM dropid (NOLOCK) WHERE Dropid = @cDropID)
         BEGIN
            SET @nErrNo = 217933
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDIsUsed
         END
            
         ELSE IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE STORERKEY = @cStorerKey AND STATUS <> '9' AND dropid = @cDropID 
         AND (@LocationType NOT IN ('PICK','CASE') 
         OR (SELECT TOP 1 ID FROM pickdetail (NOLOCK) WHERE STORERKEY = @cStorerKey AND STATUS <> '9' AND Dropid = @cDropID)<>''))
         BEGIN
            SET @nErrNo = 217934
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDUsedforPAL
         END

         ELSE IF isnull(@cPickZone,'') = '' AND (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
         BEGIN
            SET @nErrNo = 217935
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKzoneNeeded
         END
         
         ELSE IF NOT EXISTS (SELECT 1 FROM loc (NOLOCK) WHERE Facility = @cFacility and PickZone = case when @cPickZone = '' then  
            (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) else @cPickZone end
            AND loc = @cLOC)
         BEGIN
            SET @nErrNo = 217936
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotInPkZone
         END
	  END

	  If @nStep = 4 and @nInputKey = 1
	  BEGIN
         IF @nTaskQTY <> (select top 1 i_field15 from rdt.RDTMOBREC where Mobile = @nMobile)
            and @LocationType not in ('PICK','CASE')
         BEGIN
            SET @nErrNo = 218000
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Confirm qty as shown'
         END
      END
   END
END

GO