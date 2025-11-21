SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_897ExtValidSP02                                       */
/* Purpose: Validate UCC                                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-01-11 1.0  James    WMS3779. Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_897ExtValidSP02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15), 
   @cDropID          NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cPOKey         NVARCHAR( 10) 
          ,@cPOLineNumber  NVARCHAR( 5)
          ,@cSourcekey     NVARCHAR( 20)
          ,@cUCC           NVARCHAR( 20)
          ,@nUCCQty        INT
          ,@cStatus        NVARCHAR( 10)
          ,@nASNStatus     NVARCHAR( 10)


   DECLARE
      @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
      @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
      @cErrMsg5    NVARCHAR( 20)

   SET @nErrNo = 0

   SELECT @cUCC = I_Field01 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 897
   BEGIN
      IF @nStep = 1 -- From  id
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF NOT EXISTS (
               SELECT 1 FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cUCC)
            BEGIN
               SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 118651, @cLangCode, 'DSP'), 7, 14) --CARTON ID DOES
               SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 118652, @cLangCode, 'DSP'), 7, 14) --NOT EXISTS
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
               END  

               SET @nErrNo = 118651
               GOTO Quit
            END

            DECLARE CUR_CHKUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT  SourceKey, Qty, Status
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   UCCNo = @cUCC
            OPEN CUR_CHKUCC
            FETCH NEXT FROM CUR_CHKUCC INTO @cSourceKey, @nUCCQty, @cStatus
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF ISNULL( @cStatus, '') > '0'
               BEGIN  
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 118653, @cLangCode, 'DSP'), 7, 14) --CARTON ID 
                  SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 118654, @cLangCode, 'DSP'), 7, 14) --ALREADY 
                  SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 118655, @cLangCode, 'DSP'), 7, 14) --RECEIVED 
                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                  END         

                  SET @nErrNo = 118653
                  BREAK
               END  

               IF ISNULL( @cSourceKey, '') = '' 
               BEGIN  
                  SET @nErrNo = 118656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No asn found'  
                  BREAK
               END  

               SET @cPOKey = SUBSTRING( @cSourceKey, 1, 10)
               SET @cPOLineNumber = SUBSTRING( @cSourceKey, 11, 5)
      
               SET @nASNStatus = ''
               SELECT @nASNStatus = R.Status
               FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
               JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
               WHERE RD.StorerKey = @cStorerKey
               AND   RD.POKey = @cPOKey
               AND   RD.POLineNumber = @cPOLineNumber

               -- Check if ASN populated
               IF ISNULL( @nASNStatus, '') = ''
               BEGIN  
                  SET @nErrNo = 118657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Asn not exists'  
                  BREAK
               END  

               IF @nASNStatus = '9'
               BEGIN  
                  SET @nErrNo = 118658
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Asn Closed'  
                  BREAK
               END  

               FETCH NEXT FROM CUR_CHKUCC INTO @cSourceKey, @nUCCQty, @cStatus
            END
            CLOSE CUR_CHKUCC
            DEALLOCATE CUR_CHKUCC
         END
      END
   END
   
Quit:





GO