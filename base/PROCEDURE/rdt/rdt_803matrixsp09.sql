SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803MatrixSP09                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 16-02-2021 1.0  yeekung  WMS-18729 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_803MatrixSP09] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT 
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR( 5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cLight     NVARCHAR( 1)
   ,@cStation   NVARCHAR( 10)  
   ,@cMethod    NVARCHAR( 1)  
   ,@cSKU       NVARCHAR( 20)
   ,@cIPAddress NVARCHAR( 40)
   ,@cPosition  NVARCHAR( 10)
   ,@cDisplay   NVARCHAR( 10)
   ,@nErrNo     INT            OUTPUT
   ,@cErrMsg    NVARCHAR( 20)  OUTPUT
   ,@cResult01  NVARCHAR( 20)  OUTPUT
   ,@cResult02  NVARCHAR( 20)  OUTPUT
   ,@cResult03  NVARCHAR( 20)  OUTPUT
   ,@cResult04  NVARCHAR( 20)  OUTPUT
   ,@cResult05  NVARCHAR( 20)  OUTPUT
   ,@cResult06  NVARCHAR( 20)  OUTPUT
   ,@cResult07  NVARCHAR( 20)  OUTPUT
   ,@cResult08  NVARCHAR( 20)  OUTPUT
   ,@cResult09  NVARCHAR( 20)  OUTPUT
   ,@cResult10  NVARCHAR( 20)  OUTPUT
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   DECLARE @i        INT
   DECLARE @nStart   INT 
   DECLARE @nEnd     INT 
   DECLARE @nLen     INT
   DECLARE @cCR      NVARCHAR( 1)
   DECLARE @cLF      NVARCHAR( 1)
   DECLARE @cASCII   NVARCHAR( 4000)
   DECLARE @cResult  NVARCHAR( 20)
   DECLARE @cLogicalName NVARCHAR( 10)

	-- Get assign info
	DECLARE @cOrderKey NVARCHAR( 10)
	DECLARE @cLoadkey NVARCHAR( 20),
				@cWaveKey NVARCHAR(20),
				@cdropid  NVARCHAR(20)
   
   SET @cCR = CHAR( 13)
   SET @cLF = CHAR( 10)
   SET @cResult01 = ''
   SET @cResult02 = ''
   SET @cResult03 = ''
   SET @cResult04 = ''
   SET @cResult05 = ''
   SET @cResult06 = ''
   SET @cResult07 = ''
   SET @cResult08 = ''
   SET @cResult09 = ''
   SET @cResult10 = ''

	DECLARE @cToTalOpen INT = 0,
				@cTotalBatchOrder INT = 0,
				@cSortedQty INT = 0,
				@cToTalQty INT = 0,
				@cBatchNo NVARCHAR(20)
   
	SELECT 
		@cOrderKey	= OrderKey,
		@cLoadkey	= loadkey,
		@cWaveKey   = wavekey,
		@cdropid    = dropid
	FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
	WHERE Station = @cStation
		AND IPAddress = @cIPAddress
		AND Position = @cPosition

   SELECT @cWaveKey=wavekey
   FROM PICKDETAIL (NOLOCK) 
   where orderkey=@cOrderKey

   SELECT @cToTalOpen=count(*)
	from Orders (nolock)
	where LoadKey=@cLoadkey
      AND status>='5'

   SELECT @cTotalBatchOrder=count(*)
	from Orders (nolock)
	where LoadKey=@cLoadkey

   SELECT @cToTalQty=sum(qty) 
   from pickdetail pd (nolock) 
   join orders o (nolock) on pd.OrderKey=o.orderkey
   where LoadKey=@cLoadkey
      AND pd.storerkey=@cstorerkey

	SELECT @cSortedQty=sum(qty)
	from pickdetail pd (nolock) 
   join orders o (nolock) on pd.OrderKey=o.orderkey
	where LoadKey=@cLoadkey
   AND pd.storerkey=@cstorerkey
   AND caseid ='SORTED'

	SELECT @cBatchNo=lottable02
	from pickdetail (nolock)pd
	JOIN lotattribute (nolock)lot ON pd.lot=lot.lot and pd.sku=lot.sku 
	where pd.orderkey=@cOrderKey
		AND pd.storerkey=@cstorerkey
		and dropid=@cdropid
		and pd.sku=@csku

	SET @cResult01 = 'WaveID: ' + @cWaveKey
	SET @cResult02 = 'Loadkey:' + @cLoadkey
	SET @cResult03 = 'SORT/TTLORD: ' +  CAST (@cToTalOpen AS NVARCHAR(20)) + '/' + CAST (@cTotalBatchOrder AS NVARCHAR(20))
	SET @cResult04 = 'SORT/TTLQTY: ' + CAST (@cSortedQty AS NVARCHAR(20)) + '/' + CAST (@cToTalQty AS NVARCHAR(20))
	SET @cResult05 = @cBatchNo
   SET @cResult06 = @cPosition

   IF NOT EXISTS(SELECT 1
		         FROM PickDetail pd WITH (NOLOCK)
		         JOIN orders o (nolock) ON pd.storerkey=o.storerkey and pd.orderkey=o.orderkey
		         WHERE pd.StorerKey = @cStorerKey 
			         AND o.loadkey=@cLoadkey
                  AND ISNULL(PD.CASEID,'') = ''
			         AND pd.[Status] <= '5')
   BEGIN
      SET @cResult10='Sort End'
   END

   IF @cLight ='1'
   BEGIN
      DECLARE @bSuccess    INT
      DECLARE @cLightMode  NVARCHAR(4)

      IF @cDisplay = ''
         SET @cDisplay = '1'

	   DECLARE @cLightModeBatch NVARCHAR(20)

	   SET @cLightModeBatch = rdt.RDTGetConfig( @nFunc, 'LightModeBatch', @cStorerKey)
      SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

      -- Off all lights
	   EXEC  PTL.isp_PTL_TerminateModuleSingle
			   @cStorerKey
			   ,@nFunc
			   ,@cStation
			   ,@cPosition
			   ,@bSuccess    OUTPUT
			   ,@nErrNo       OUTPUT
			   ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
         ,@n_PTLKey         = 0
         ,@c_DisplayValue   = @cDisplay 
         ,@b_Success        = @bSuccess    OUTPUT    
         ,@n_Err            = @nErrNo      OUTPUT  
         ,@c_ErrMsg         = @cErrMsg     OUTPUT
         ,@c_DeviceID       = @cStation
         ,@c_DevicePos      = @cPosition
         ,@c_DeviceIP       = @cIPAddress  
         ,@c_LModMode       = @cLightMode
      IF @nErrNo <> 0
         GOTO Quit

	   SELECT 
		   @cPosition=deviceposition,
		   @cIPAddress=ipaddress
	   FROM deviceprofile WITH (NOLOCK) 
	   WHERE deviceid = @cStation
	   and storerkey=@cStorerKey
	   and logicalname='batch'

	   SET @cDisplay=@cBatchNo

	   -- Off all lights
	   EXEC  PTL.isp_PTL_TerminateModuleSingle
			   @cStorerKey
            ,@nFunc
            ,@cStation
			   ,@cPosition
			   ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF ISNULL(@cDisplay,'')<>''
      BEGIN
      
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = @cDisplay 
            ,@b_Success        = @bSuccess    OUTPUT    
            ,@n_Err            = @nErrNo      OUTPUT  
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cPosition
            ,@c_DeviceIP       = @cIPAddress  
            ,@c_LModMode       = '14'
            ,@c_DeviceModel    = 'BATCH'
         IF @nErrNo <> 0
               GOTO Quit
      END
   END

Quit:

END

GO