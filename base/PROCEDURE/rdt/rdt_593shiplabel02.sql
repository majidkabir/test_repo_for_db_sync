SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel02                                     */  
/*                                                                         */  
/* Purpose: User key in orderkey. Screen display a list of carton no       */  
/*          for user to see. User key in orderkey + carton no to reprint.  */
/*          If fail to reprint, request the printing from web service      */
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2013-05-20 1.0  James    SOS368192 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593ShipLabel02] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),  -- Reprint from web service  
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cOrderKey     NVARCHAR( 10)  
          ,@cLoadKey      NVARCHAR( 10)  
          ,@cShipperKey   NVARCHAR( 15) 
          ,@cStatus       NVARCHAR( 10)  
          ,@cCartonNo     NVARCHAR( 5) 
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
          ,@cReprint      NVARCHAR( 10) 
          ,@cUserName     NVARCHAR( 18) 
          ,@cFacility     NVARCHAR( 5)  
          ,@cPrintData    NVARCHAR( MAX)   
          ,@nRowRef       INT
          ,@nCnt          INT
          ,@nCartonNo     INT
          ,@bSuccess      INT
          ,@cLabelNo      NVARCHAR( 20)
          ,@cTrackingNo   NVARCHAR( 20) 
          ,@cTransmitLogKey   NVARCHAR( 10)
   
   DECLARE @cErrMsg1    NVARCHAR( 20),
           @cErrMsg2    NVARCHAR( 20),
           @cErrMsg3    NVARCHAR( 20),
           @cErrMsg4    NVARCHAR( 20),
           @cErrMsg5    NVARCHAR( 20),
           @cErrMsg6    NVARCHAR( 20),
           @cErrMsg7    NVARCHAR( 20),
           @cErrMsg8    NVARCHAR( 20),
           @cErrMsg9    NVARCHAR( 20),
           @cErrMsg10   NVARCHAR( 20)

   SET @cOrderKey = @cParam1
   SET @cCartonNo = ISNULL( @cParam2, '')
   SET @cReprint = @cParam3

   SELECT @cUserName = UserName, 
          @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 100851  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   SELECT @cStatus = [Status]
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cStatus, '') = ''
   BEGIN  
      SET @nErrNo = 100852  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
      GOTO Quit  
   END  

   IF ISNULL( @cStatus, '') < '5'
    BEGIN  
      SET @nErrNo = 100853  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit  
   END  

   IF ISNULL( @cStatus, '') = '9'
   BEGIN  
      SET @nErrNo = 100854  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORDERS SHIPPED
      GOTO Quit  
   END  

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cPickSlipNo, '') = ''
   BEGIN  
      SET @nErrNo = 100855  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO PKSLIP NO
      GOTO Quit  
   END  

   -- If key in orderkey only then show screen with carton no
   -- to let user choose which carton to print
   IF ISNULL( @cCartonNo, '') = '' AND @cReprint = ''
   BEGIN
      SET @nCnt = 1
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT CartonNo, LABELNO 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo
      ORDER BY 1
      OPEN CUR_LOOP 
      FETCH NEXT FROM CUR_LOOP INTO @nCartonNo, @cLabelNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @cTrackingNo = @cLabelNo

         IF @nCnt = 1
            SET @cErrMsg1 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 2
            SET @cErrMsg2 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 3
            SET @cErrMsg3 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 4
            SET @cErrMsg4 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 5
            SET @cErrMsg5 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 6
            SET @cErrMsg6 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 7
            SET @cErrMsg7 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 8
            SET @cErrMsg8 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 9
            SET @cErrMsg9 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         IF @nCnt = 10
            SET @cErrMsg10 = CAST( @nCartonNo AS NVARCHAR( 2)) + '.' + @cTrackingNo

         SET @nCnt = @nCnt + 1

         FETCH NEXT FROM CUR_LOOP INTO @nCartonNo, @cLabelNo
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      IF ISNULL( @cErrMsg1, '') <> ''
      BEGIN
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
              @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5,
              @cErrMsg6, @cErrMsg7, @cErrMsg8, @cErrMsg9, @cErrMsg10

         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
            SET @cErrMsg6 = ''
            SET @cErrMsg7 = ''
            SET @cErrMsg8 = ''
            SET @cErrMsg9 = ''
            SET @cErrMsg10 = ''
         END
            
         SET @nErrNo = 0
         
         EXEC rdt.rdtSetFocusField @nMobile, 4  -- set focus on carton no

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nErrNo = 100856  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO RECORD
         GOTO Quit  
      END
   END
   ELSE
   BEGIN
      SELECT @cTrackingNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo
      AND   CartonNo = CAST( @cCartonNo AS INT)

      SELECT @cPrintData = PrintData,
             @nRowRef = RowRef
      FROM dbo.CartonTrack WITH (NOLOCK)
      WHERE TrackingNo = @cTrackingNo
      AND   KeyName = @cStorerKey
      AND   LabelNo = @cOrderKey
   END

   IF @cReprint = '1'
   BEGIN
      SET @cTransmitLogKey = ''
      SELECT @cTransmitLogKey = TransmitLogKey 
      FROM dbo.TransmitLog2 WITH (NOLOCK) 
      WHERE Key1 = @nRowRef
      AND   Key3 = @cStorerkey
      AND   TableName = 'WSCRTRACKNOMP'

      IF ISNULL( @cTransmitLogKey, '') <> ''
      BEGIN
         DELETE FROM TransmitLog2 WHERE TransmitLogKey = @cTransmitLogKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100858  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DEL TL2 FAIL
            GOTO Quit  
         END
      END

      -- Trigger metapack here to print label
      SET @bSuccess = 1

      -- Insert transmitlog2 here
      EXEC ispGenTransmitLog2 
          @c_TableName        = 'WSCRTRACKNOMP'
         ,@c_Key1             = @nRowRef
         ,@c_Key2             = ''
         ,@c_Key3             = @cStorerkey
         ,@c_TransmitBatch    = ''
         ,@b_Success          = @bSuccess    OUTPUT
         ,@n_err              = @nErrNo      OUTPUT
         ,@c_errmsg           = @cErrMsg     OUTPUT      

      -- Insert TL2 here only, the web service will do the printing
      -- quit after excute      
      IF @bSuccess <> 1    
         GOTO Quit
      ELSE
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END
   END

   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Ship Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 100857  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

   EXECUTE dbo.isp_PrintZplLabel
       @cStorerKey        = @cStorerKey
      ,@cLabelNo          = ''
      ,@cTrackingNo       = @cTrackingNo
      ,@cPrinter          = @cLabelPrinter
      ,@nErrNo            = @nErrNo    OUTPUT
      ,@cErrMsg           = @cErrMsg   OUTPUT

Quit:  

GO