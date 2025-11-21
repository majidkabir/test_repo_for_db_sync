SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_610AdHocGenCC01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Ad-hoc generate StockTakeSheetParameters, CCDetail          */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-May-2006 1.0  Ung      WMS-17071 Created                          */
/************************************************************************/
CREATE PROC [RDT].[rdt_610AdHocGenCC01] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cFacility       NVARCHAR( 5), 
   @cStorerKey      NVARCHAR( 15),
   @cCCRefNo        NVARCHAR( 10),
   @cLOC            NVARCHAR( 10),
   @cCCSheetNo      NVARCHAR( 10) OUTPUT,
   @nCCCountNo      INT           OUTPUT,
   @cSuggestLOC     NVARCHAR( 10) OUTPUT,
   @cSuggestLogiLOC NVARCHAR( 18) OUTPUT,
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get ad-hoc CCRef
   DECLARE @cAdHocCCRef NVARCHAR(10)
   SET @cAdHocCCRef = rdt.RDTGetConfig( @nFunc, 'AdHocCCRef', @cStorerKey) 
   IF @cAdHocCCRef = '0'
      SET @cAdHocCCRef = ''

   IF @nFunc = 610 -- Cycle count
   BEGIN
      IF @nStep = 1 -- CCRef
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check ad-hoc CCRef setup
            IF @cAdHocCCRef = ''
            BEGIN
               SET @nErrNo = 171501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup CCREF
               GOTO Quit
            END         

            -- CCRef is ad-hoc
            IF @cAdHocCCRef = @cCCRefNo
            BEGIN
               -- Check ad-hoc CCRef valid
               IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.StockTakeSheetParameters WITH (NOLOCK) WHERE StockTakeKey = @cCCRefNo)
               BEGIN
                  SET @nErrNo = 171502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CCRef NotFound
                  GOTO Quit
               END         

               -- Default
               SET @cCCSheetNo = CONVERT( NVARCHAR(6), GETDATE(), 12) + '001' --YYMMDD999
               SET @nCCCountNo = 1
            END
            ELSE   
               SET @nErrNo = -1 -- Pass thru as normal CCRef
         END
      END

      IF @nStep = 4 -- LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- CCRef is ad-hoc
            IF @cAdHocCCRef = @cCCRefNo AND @cLOC <> ''
            BEGIN
               -- Get LOC info
               DECLARE @cChkFacility NVARCHAR( 5)
               DECLARE @cChkSuggestLogiLOC NVARCHAR( 18)
               SELECT TOP 1
                  @cChkFacility = Facility, 
                  @cChkSuggestLogiLOC = ISNULL( CCLogicalLOC, '')
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cLOC

               -- Check LOC valid
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 171503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Facility Diff
                  GOTO Quit
               END

               -- Check same facility
               IF @cChkFacility <> @cFacility
               BEGIN
                  SET @nErrNo = 171504
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Facility Diff
                  GOTO Quit
               END

               -- Check CCLogicalLOC setup
               IF @cChkSuggestLogiLOC = ''
               BEGIN
                  SET @nErrNo = 171505
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup LogiLOC
                  GOTO Quit
               END
               
               -- Generate CCDetail
               IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.CCDetail WITH (NOLOCK) WHERE CCKey = @cCCRefNo AND LOC = @cLOC AND CCSheetNo = @cCCSheetNo)
               BEGIN
                  EXEC dbo.ispRDTGenCountSheet
                      @c_StockTakeKey  = @cCCRefNo  
                     ,@c_LOC           = @cLOC
                     ,@c_SKU           = ''  
                     ,@c_TaskDetailKey = @cCCSheetNo
               END
               
               SET @cSuggestLOC = @cLOC
               SET @cSuggestLogiLOC = @cChkSuggestLogiLOC
            END
         END
      END
   END   

Quit:

END

GO