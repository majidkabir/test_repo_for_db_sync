SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593UCCLabel06                                      */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2021-03-09 1.0  Chermaine  WMS-16510 Created (dup rdt_593UCCLabel05)    */ 
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593UCCLabel06] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- UCCNo
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @cLabelPrinter NVARCHAR( 10)  
   DECLARE @cPaperPrinter NVARCHAR( 10)  
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cToteID       NVARCHAR( 10)  
   DECLARE @cWavekey      NVARCHAR( 10)
   DECLARE @cWaveCount    INT
   DECLARE @nRowCount     INT
   
   SET @cToteID    = @cParam1

   -- Check blank
   IF @cToteID = ''
   BEGIN
      SET @nErrNo = 164501  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need ID
      GOTO Quit  
   END

   -- Get login info
   SELECT 
      @cFacility = Facility, 
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   -- Get ID info
   SET @cWaveCount = '0'
   SELECT @cWaveCount = COUNT(DISTINCT WAVEKEY) 
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE DROPID = @cToteID
   AND   STATUS = '3'
   AND   STORERKEY = @cStorerKey

   -- Check valid ID
   IF @cWaveCount > 1
   BEGIN  
      SET @nErrNo = 164502  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid dropid 
      GOTO Quit  
   END  

   SELECT  @cWavekey = WAVEKEY FROM PICKDETAIL WITH (NOLOCK)
   WHERE DROPID = @cToteID
   AND   STATUS = '3'
   AND   STORERKEY = @cStorerKey

   -- Multi SKU
   IF EXISTS (SELECT 1 FROM TRANSMITLOG3 WITH (NOLOCK)
             WHERE TABLENAME = 'DPIDRDTLOG'
			 AND   KEY1 = @cToteID
			 AND   KEY2 = @cWavekey
			 AND   KEY3 = @cStorerKey)
   BEGIN  
      SET @nErrNo = 164503  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CLOSED  
      GOTO Quit  
   END  

       
   /*-------------------------------------------------------------------------------  
  
                                    Print UCC Label  
  
   -------------------------------------------------------------------------------*/  
   -- Common params
   DECLARE @cKey2       NVARCHAR( 30) = ''
   DECLARE @cTransmitlogkey   NVARCHAR( 10)
   DECLARE @cTransmitflag     NVARCHAR( 5)
   DECLARE @bSuccess    INT

   EXECUTE ispGenTransmitLog3 
   @c_TableName      = 'DPIDRDTLOG', 
   @c_Key1           = @cToteID, 
   @c_Key2           = @cWavekey, 
   @c_Key3           = @cStorerkey, 
   @c_TransmitBatch  = '', 
   @b_Success        = @bSuccess   OUTPUT,    
   @n_err            = @nErrNo     OUTPUT,    
   @c_errmsg         = @cErrMsg    OUTPUT    

   IF @bSuccess <> 1    
   BEGIN
      SET @nErrNo = 164504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertTL3 Fail
      GOTO Quit
   END

Quit:  

GO