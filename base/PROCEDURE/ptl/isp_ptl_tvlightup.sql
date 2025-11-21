SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure:  isp_PTL_TVLightUp                                       */
/* Copyright: IDS                                                             */
/* Purpose: THG PTL                                                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-06-24 1.0  YeeKung    WMS-9312 Created                                */
/* 2019-10-02 1.1  YeeKung    Change to dynamic path                          */
/* 2019-11-01 1.2  YeeKung    WMS-10796 PTL and TV remove dependency          */
/******************************************************************************/

CREATE PROC [PTL].[isp_PTL_TVLightUp]
(
   @n_Func               INT
   ,@n_PTLKey            BIGINT
   ,@b_Success           INT OUTPUT
   ,@n_Err               INT OUTPUT
   ,@c_ErrMsg            NVARCHAR(215) OUTPUT
   ,@c_DeviceID          NVARCHAR(20) = ''
   ,@cLightModeColor     NVARCHAR(10) = ''
   ,@c_InputType         NVARCHAR(20) = ''
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_TCPMessage        VARCHAR(max),
            @n_IsRDT             INT,
            @n_Continue          INT,
            @c_LightAction       NVARCHAR(20),
            @n_LenOfValues       INT,
            @c_CommandValue      NVARCHAR(15),
            @nTranCount          INT,
            @cURLMessage         NVARCHAR(MAX),
            @c_TrafficMessage    NVARCHAR(MAX),
            @c_TrafficMessage1   NVARCHAR(MAX)

   DECLARE  @c_StorerKey         NVARCHAR(15),
            @cSKU                NVARCHAR(20),
            @cSKUEncode          NVARCHAR(20),
            @cLoc                NVARCHAR(10),
            @cLocEncode          NVARCHAR(10),
            @cSKUDesc            NVARCHAR(MAX),
            @cSKUDescEncode      NVARCHAR(MAX),
            @cQty                INT,
            @n_LightLinkLogKey   INT,
            @dAddDate            DATETIME,
            @cMaxUser            INT,
            @Userno              INT,
            @cUserID             NVARCHAR(10),
            @cStatus             NVARCHAR(1),
            @c_IniFilePath       NVARCHAR(100),
            @cDevicePosition     Nvarchar(20),
            @cLangCode           NVARCHAR( 3),
            @c_vbErrMsg          NVARCHAR(MAX),
            @cRemark             NVARCHAR(2),
            @cTVStatus           NVARCHAR(1)

   SET @UserNo = 0
   SET @cMaxUser =1 --rdt.RDTGetConfig( @nFunc, 'MaxUser', @cStorerKey)
   SET @cLangCode ='ENG'

   SELECT  TOP 1
      @cSKU = PT.SKU,
      @cSKUDESC = SKU.DESCR,
      @cLOC= PT.DeviceID,
      @cQty = PT.ExpectedQty,
      @cUserID = PT.AddWho,
      @cDevicePosition = PT.deviceposition,
      @c_StorerKey = PT.StorerKey,
      @cRemark = PT.Remarks
   FROM PTL.PTLTRAN  PT WITH (NOLOCK) JOIN DBO.SKU SKU WITH (NOLOCK)
   ON PT.SKU=SKU.SKU
   WHERE PT.PTLKEY=@n_PTLKey
      AND   PT.[Status]<>'9'

   SET @cStatus = 1

   IF (ISNULL(@c_DeviceID,'')='')
   BEGIN

      IF (ISNULL(@cUserID,'')='')
      BEGIN
         SELECT  TOP 1
         @cUserID = PT.AddWho
         ,@c_StorerKey = StorerKey
         FROM PTL.PTLTRAN  PT WITH (NOLOCK)
         WHERE PT.PTLKEY=@n_PTLKey
            AND   PT.[Status]='9'
      END

      SELECT @c_DeviceID = MonitorID
      FROM  [dbo].[PTLTrafficDetail] WITH (NOLOCK)
      WHERE UserID = @cUserID
         AND status='1'
   END

   SELECT TOP 1
   @c_IniFilePath = c.UDF02
   ,@cTVStatus = c.UDF04
   FROM CODELKUP c WITH (NOLOCK)
   WHERE ListName    = 'TCPClient'
      AND   c.Short     = 'TV'
      AND   c.code      = @c_DeviceID

   --IF @c_DeviceID in('TV0001','TV0002')
   --   SET @c_IniFilePath = 'file:///C:/Users/LFLTHGPTL01/Documents/TestHTML/TestHTML/Title.html'
   --ELSE IF @c_DeviceID in('TV0003','TV0004')
   --   SET @c_IniFilePath = 'file:///C:/Users/LFLTHGPTL02/Documents/TestHTML/TestHTML/Title.html'
   --ELSE IF @c_DeviceID in('TV0005','TV0006')
   --   SET @c_IniFilePath = 'file:///C:/Users/LFLTHGPTL03/Documents/TestHTML/TestHTML/Title.html'
   IF (@cTVStatus ='1')
   BEGIN
      EXECUTE MASTER.DBO.isp_URLEncode
      @c_InputString = @cSKU
      , @c_OutputString = @cSKUEncode OUTPUT
      , @c_vbErrMsg     = @c_vbErrMsg OUTPUT

      IF ISNULL(@c_vbErrMsg ,'') <>''
      BEGIN
         GOTO Quit
      END

      EXECUTE MASTER.DBO.isp_URLEncode
      @c_InputString = @cSKUDESC
      , @c_OutputString = @cSKUDESCEncode OUTPUT
      , @c_vbErrMsg     = @c_vbErrMsg OUTPUT

      IF ISNULL(@c_vbErrMsg ,'') <>''
      BEGIN
         GOTO Quit
      END

      EXECUTE MASTER.DBO.isp_URLEncode
      @c_InputString = @cLOC
      , @c_OutputString = @cLOCEncode OUTPUT
      , @c_vbErrMsg     = @c_vbErrMsg OUTPUT

      IF ISNULL(@c_vbErrMsg ,'') <>''
      BEGIN
         GOTO Quit
      END

      SET @c_TrafficMessage = '' 
      SET @c_TrafficMessage1 = ''

      IF @c_InputType = 'Hold'
      BEGIN
         SET @cURLMessage = @c_IniFilePath+'?color='+CASE WHEN @cLightModeColor='Red'      THEN 'R'
                           WHEN @cLightModeColor='Blue'     THEN 'B'
                           WHEN @cLightModeColor='LightBlue'THEN 'LB'
                           WHEN @cLightModeColor='Green'    THEN 'G'
                           WHEN @cLightModeColor='Yellow'   THEN 'Y'
                           WHEN @cLightModeColor='Orange'   THEN 'O'
                           WHEN @cLightModeColor='Black'    THEN 'BK'
                           WHEN @cLightModeColor='Purple'   THEN 'P'
                           Else 'W'  END
                           +'&sku='+ @cSKUEncode
                           +'&sdesc='+ @cSKUDESCEncode
                           +'&qty='+@cRemark+' '+CAST(@cQty AS NVARCHAR(6))
                           +'&loc='+ @cLOCEncode
                           +'&hold='+'1'
      END
      ELSE IF ((ISNULL(@cSKU,'')='' )OR (ISNULL(@cDevicePosition,'')='') OR (ISNULL(@cLOC,'')='') )
      BEGIN
         SET @cURLMessage = @c_IniFilePath+'?color=BK'+
         +'&sku='+ @cSKUEncode
         +'&sdesc='+ @cSKUDESCEncode
         +'&qty='+@cRemark+' '+CAST(@cQty AS NVARCHAR(6))
         +'&loc='+ @cLOCEncode
         +'&hold='+'0'

         SET @cStatus = 0
      END
      ELSE
      BEGIN
         SET @cURLMessage = @c_IniFilePath+'?color='+CASE WHEN @cLightModeColor='Red'      THEN 'R'
         WHEN @cLightModeColor='Blue'     THEN 'B'
         WHEN @cLightModeColor='LightBlue'THEN 'LB'
         WHEN @cLightModeColor='Green'    THEN 'G'
         WHEN @cLightModeColor='Yellow'   THEN 'Y'
         WHEN @cLightModeColor='Orange'   THEN 'O'
         WHEN @cLightModeColor='Black'    THEN 'BK'
         WHEN @cLightModeColor='Purple'   THEN 'P'
         Else 'W'  END
         +'&sku='+ @cSKUEncode
         +'&sdesc='+ @cSKUDESCEncode
         +'&qty='+@cRemark+' '+CAST(@cQty AS NVARCHAR(6))
         +'&loc='+ @cLOCEncode
         +'&hold='+'0'
      END
      SET @cMaxUser = 2
      SET @UserNo = 0

      IF @cMaxUser = 2
      BEGIN

         SET @c_TCPMessage ='UCC|['

         IF NOT EXISTS (SELECT 1 FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
         WHERE MonitorID = @c_DeviceID)
         BEGIN
            SET @c_TrafficMessage = '{"ID":'+CAST(@UserNo AS NVARCHAR(6))+',"Active":true,"ChartName":null,"RDLC":null,"URL":"'+@cURLMessage+'","Params":null,"RefreshIntv":10}'

            INSERT INTO [dbo].[PTLTrafficDetail] (UserID,PTLKey,MonitorID,USERNO,TrafficData,status)
            VALUES(@cUserID,@n_PTLKey,@c_DeviceID,@UserNo,@c_TrafficMessage,@cStatus)

            IF @@ERROR <> 0
            BEGIN
               SET @n_Err = 141751
               --SET @cErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP') --'InsDProfileLogFail'
               GOTO Quit
            END

            SET @cURLMessage = @c_IniFilePath+'?color=BK'+
            +'&sku='
            +'&sdesc='
            +'&qty='
            +'&loc='
            +'&hold='+'0'

            SET @c_TrafficMessage1 = '{"ID":'+'1'+',"Active":true,"ChartName":null,"RDLC":null,"URL":"'+@cURLMessage+'","Params":null,"RefreshIntv":10}'

            INSERT INTO [dbo].[PTLTrafficDetail] (UserID,PTLKey,MonitorID,USERNO,TrafficData,status)
            VALUES('','',@c_DeviceID,'1',@c_TrafficMessage1,'0')

            SET @c_TCPMessage =@c_TCPMessage+@c_TrafficMessage+ ','+@c_TrafficMessage1

            SET @UserNo = @UserNo+2
         END
         ELSE IF EXISTS (SELECT TOP 1 * FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
         WHERE MonitorID = @c_DeviceID
            AND UserID = @cUserID
            AND status =1
         ORDER BY adddate DESC )
         BEGIN
            SELECT TOP 1 @UserNo=USERNO
            FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
            WHERE MonitorID = @c_DeviceID AND UserID = @cUserID
            order by userno

            SET @c_TrafficMessage = '{"ID":'+CAST(@UserNo AS NVARCHAR(6))+',"Active":true,"ChartName":null,"RDLC":null,"URL":"'+@cURLMessage+'","Params":null,"RefreshIntv":10}'

            UPDATE [dbo].[PTLTrafficDetail] WITH (ROWLOCK)
            SET UserID = case when(isnull(@cUserID,''))='' then '' else @cUserID end
               ,PTLKey = case when(isnull(@n_PTLKey,''))='' then '' else @n_PTLKey end
               ,TrafficData = case when(isnull(@c_TrafficMessage,''))='' then null else @c_TrafficMessage end
               ,Status = case when(isnull(@cStatus,''))='' then '0' else  @cStatus end
               ,adddate = getdate()
            WHERE MonitorID = @c_DeviceID 
                  AND UserID = @cUserID 
                  AND USERNO=@UserNo
         END
         ELSE IF EXISTS (SELECT TOP 1 * FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
         WHERE MonitorID = @c_DeviceID  AND status =0 order by adddate desc )
         BEGIN

            SELECT TOP 1 @UserNo=USERNO
            FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
            WHERE MonitorID = @c_DeviceID AND STATUS=0
            ORDER BY userno

            SET @c_TrafficMessage = '{"ID":'+CAST(@UserNo AS NVARCHAR(6))+',"Active":true,"ChartName":null,"RDLC":null,"URL":"'+@cURLMessage+'","Params":null,"RefreshIntv":10}'

            UPDATE [dbo].[PTLTrafficDetail] WITH (ROWLOCK)
            SET UserID = case when(isnull(@cUserID,''))='' then '' else @cUserID end
               ,PTLKey = case when(isnull(@n_PTLKey,''))='' then '' else @n_PTLKey end
               ,TrafficData = case when(isnull(@c_TrafficMessage,''))='' then null else @c_TrafficMessage end
               ,Status = '1'
               ,adddate = getdate()
            WHERE MonitorID = @c_DeviceID 
               AND status =0 
               AND USERNO=@UserNo
         END
         ELSE
         BEGIN

            SELECT TOP 1 @UserNo=USERNO
            FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
            WHERE MonitorID = @c_DeviceID AND UserID = @cUserID

            SET @c_TrafficMessage = '{"ID":'+CAST(@UserNo AS NVARCHAR(6))+',"Active":true,"ChartName":null,"RDLC":null,"URL":"'+@cURLMessage+'","Params":null,"RefreshIntv":10}'

            UPDATE [dbo].[PTLTrafficDetail] WITH (ROWLOCK)
            SET UserID = case when(isnull(@cUserID,''))='' then '' else @cUserID end
            ,PTLKey = case when(isnull(@n_PTLKey,''))='' then '' else @n_PTLKey end
            ,TrafficData = case when(isnull(@c_TrafficMessage,''))='' then null else @c_TrafficMessage end
            ,Status = case when(isnull(@cStatus,''))='' then '0' else  @cStatus end
            ,adddate = getdate()
            WHERE MonitorID = @c_DeviceID AND UserID = @cUserID AND USERNO=@UserNo
         END

         SET @c_TrafficMessage =''
         SET @UserNo = 0

         WHILE (@UserNo <@cMaxUser)
         BEGIN
            SELECT  @c_TrafficMessage = TrafficData
            FROM [dbo].[PTLTrafficDetail] WITH (NOLOCK)
            WHERE MonitorID = @c_DeviceID AND USERNO = @UserNo

            IF @UserNo  <> @cMaxUser-1
               SET @c_TrafficMessage = @c_TrafficMessage+','

            SET @c_TCPMessage = @c_TCPMessage+@c_TrafficMessage
            SET @UserNo = @UserNo+1
         END

         SET @c_TCPMessage= @c_TCPMessage+ ']'
      END

      EXEC PTL.isp_PTL_TVSendMsg
         @c_StorerKey,
         @cLangCode,
         @c_TCPMessage,
         @b_success OUTPUT,
         @n_Err OUTPUT,
         @c_ErrMsg OUTPUT,
         @c_DeviceID
      -- If error no not empty, resend the message
      IF @n_Err <> 0
      BEGIN
         SET @n_Err=0
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      IF (ISNULL(@c_DeviceID,'') <>'')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.ptltrafficdetail (NOLOCK)
                    WHERE MonitorID=@c_DeviceID AND STATUS='1')
         BEGIN
            UPDATE [dbo].[PTLTrafficDetail] 
            SET STATUS='0'
            WHERE MonitorID=@c_DeviceID AND STATUS='1' AND UserID=@cUserID
         END
      END
   END

   GOTO QUIT

   --RollBackTran:
   --   ROLLBACK TRAN isp_PTL_TVLightUp -- Only rollback change made here
   Quit:
   --WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   --   COMMIT TRAN
END

GO