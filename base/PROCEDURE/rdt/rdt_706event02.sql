SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_706Event02                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2020-09-02 1.0  YeeKung  WMS-14828 Created                              */ 
/* 2021-04-18 1.1  YeeKung  WMS-16782 Add Extendedinfo (yeekung01)         */
/***************************************************************************/

CREATE PROC [RDT].[rdt_706Event02] (
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3),          
   @nInputKey     INT,          
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cOption       NVARCHAR( 1), 
   @cRetainValue  NVARCHAR( 10),
	@cTotalCaptr   INT           OUTPUT,      
   @nStep         INT           OUTPUT,       
   @nScn          INT           OUTPUT,  
   @cLabel1       NVARCHAR( 20) OUTPUT,
   @cLabel2       NVARCHAR( 20) OUTPUT,
   @cLabel3       NVARCHAR( 20) OUTPUT,
   @cLabel4       NVARCHAR( 20) OUTPUT,
   @cLabel5       NVARCHAR( 20) OUTPUT,
   @cValue1       NVARCHAR( 60) OUTPUT,
   @cValue2       NVARCHAR( 60) OUTPUT,
   @cValue3       NVARCHAR( 60) OUTPUT,
   @cValue4       NVARCHAR( 60) OUTPUT,
   @cValue5       NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @cExtendedinfo NVARCHAR( 20) OUTPUT,  
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @cID         NVARCHAR( 20)
   DECLARE @cTrackingID NVARCHAR( 20)       
   DECLARE @cNextScreen     NVARCHAR( 1) 
   DECLARE @cOutfield02 NVARCHAR(20)     
   DECLARE @cReceiptkey NVARCHAR(20)
        
        
   -- Parameter mapping        
   SET @cID = @cValue1
   SET @cTrackingID = @cValue2

   SELECT @cOutfield02=O_Field02
   from rdt.rdtmobrec (nolock)
   where mobile=@nMobile

   SET @cNextScreen = rdt.RDTGetConfig( @nFunc, 'nextscreen', @cStorerkey) 
      
   IF  @nStep =2       
   BEGIN  
      IF @nInputKey=1
      BEGIN
         IF ISNULL(@cID,'')=''
         BEGIN
            SET @nErrNo = 159151      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDNeed    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID      
            GOTO Quit     
         END

         -- Check barcode format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0    
         BEGIN    
            SET @nErrNo = 159154    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID      
            GOTO Quit       
         END  
         
         IF ISNULL(@cOutfield02,'')=''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID      
            GOTO Quit 
         END 

         IF ISNULL(@cTrackingID,'')='' 
         BEGIN
            SET @nErrNo = 159152      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNoNeed    
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- trackingid      
            GOTO Quit 
         END

         -- Check barcode format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TrackingNo', @cTrackingID) = 0    
         BEGIN    
            SET @nErrNo = 159155   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- trackingno      
            GOTO Quit       
         END   

         IF EXISTS(SELECT 1 FROM receipt R(NOLOCK)  LEFT JOIN docinfo doc (NOLOCK) ON
                     R.receiptkey=doc.key1
                     WHERE doc.TableName='RECEIPT'
                     AND doc.storerkey=@cStorerKey
                     AND doc.key3=@cTrackingID
                     AND Facility=@cFacility)
         BEGIN
            IF EXISTS(SELECT 1 FROM receipt R(NOLOCK) LEFT JOIN docinfo doc (NOLOCK) ON
                     R.receiptkey=doc.key1
                     WHERE doc.TableName='RECEIPT'
                     AND doc.storerkey=@cStorerKey
                     AND doc.key3=@cTrackingID
                     AND Facility=@cFacility
                     AND R.userdefine02 <>'Y')
               SET @cExtendedinfo='N'
            ELSE
               SET @cExtendedinfo='Y'
         END
         ELSE
         BEGIN
            SET @cExtendedinfo='N'
         END

         INSERT INTO rdt.rdtDataCapture(storerkey,facility,V_id,v_string1)
         Values(@cStorerKey,@cFacility,@cID,@cTrackingID)

         IF @@ERROR<>0
         BEGIN
            SET @nErrNo = 159153     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNoNeed    
            SET @cValue1=''
            SET @cValue2=''
            GOTO Quit     
         END

         SET @cTotalCaptr =0

         SELECT @cTotalCaptr=COUNT(*)
         from rdt.rdtDataCapture (Nolock)
         where storerkey=@cStorerKey
         and facility=@cFacility
         and V_id=@cID

         EXEC rdt.rdtSetFocusField @nMobile, 4 -- trackingid  

         SET @cValue2=''

      END

      IF @nInputKey=0
      BEGIN
         IF @cNextScreen='1'
         BEGIN
            SET @nStep=@nStep+3
            SET @nScn=@nScn+3
            GOTO QUIT
         END
      END
	END

Quit:


GO