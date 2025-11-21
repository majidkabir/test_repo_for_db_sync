SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/    
/* Store procedure: rdt_924ExtdUpdSP02                                  */    
/* Copyright      : MAERSK                                              */    
/*                                                                      */    
/* Purpose: Scan To Truck POD Customize Update SP                       */    
/*                                                                      */    
/* Called from: 3                                                       */    
/*    1. From PowerBuilder                                              */    
/*    2. From scheduler                                                 */    
/*    3. From others stored procedures or triggers                      */    
/*    4. From interface program. DX, DTS                                */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author   Purposes                                   */    
/* 05-10-2023  1.0  yeekung  WMS-23844   Created                        */    
/************************************************************************/    
CREATE   PROC [RDT].[rdt_924ExtdUpdSP02] (    
     @nMobile      INT,             
     @nFunc        INT,             
     @cLangCode    NVARCHAR( 3),    
     @nStep        INT,             
     @cStorerKey   NVARCHAR(30),   --NL01 change to 30
     @cType        NVARCHAR(1),    
     @cMBOLKey     NVARCHAR(20),   --NL01 change to 20
     @cLoadKey     NVARCHAR(20),   --NL01 change to 20
     @cOrderKey    NVARCHAR(20),   --NL01 change to 20
     @cDoor        NVARCHAR(60),   --NL01 change to 60
     @cTruckNo     NVARCHAR(60),   --NL01 change to 60
     @cTransporter NVARCHAR(60),   --NL01 change to 60
     @nErrNo       INT OUTPUT,      
     @cErrMsg      NVARCHAR( 20) OUTPUT  
)                                
AS                               
BEGIN                            
	SET NOCOUNT ON  
	SET ANSI_NULLS OFF  
	SET QUOTED_IDENTIFIER OFF  
	SET CONCAT_NULL_YIELDS_NULL OFF  
     
	DECLARE @nTranCount INT  
     
	DECLARE  @cSQL		NVARCHAR(MAX),
			   @cUDF01	NVARCHAR(60),
			   @cUDF02	NVARCHAR(60),
			   @cUDF03	NVARCHAR(60),
			   @cSQLParams NVARCHAR(MAX)

	SET @nErrNo     = 0   
	SET @cERRMSG    = ''
	
	--S NL01
	SELECT	TOP 1 @cUDF01 = IsNull(UDF01,''), 
			         @cUDF02 = IsNull(UDF02,''), 
			         @cUDF03 = IsNull(UDF03,'') 
	FROM codelkup (NOLOCK)
	WHERE listname = 'RDT924DYN' 
	   AND Short = @nFunc
	   AND Storerkey = @cStorerKey
	   AND code = 'DYNFIELD'

	SET @nTranCount = @@TRANCOUNT  
     
	BEGIN TRAN  
	SAVE TRAN ScanToTruckUpdate  

	UPDATE rdt.rdtScanToTruck   WITH (ROWLOCK)  
	SET Status = '9'  
		,Editdate = GetDate()  
	WHERE MbolKey = CASE WHEN @cMBolKey <> '' THEN @cMBOLKey ELSE MBOLKey END  
		AND LoadKey = CASE WHEN @cLoadKey <> '' THEN @cLoadKey ELSE LoadKey END  
		AND OrderKey = CASE WHEN @cOrderKey <> '' THEN @cOrderKey ELSE OrderKey END  
	IF @@ERROR <> 0   
	BEGIN  
		SET @nErrNo = 207151  
		SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdScanToTruckFail  
		GOTO ROLLBACKTRAN  
	END  

   IF ISNULL(@cUDF01,'')<>'' OR ISNULL(@cUDF02,'')<>'' OR ISNULL(@cUDF03,'')<>''
   BEGIN
	   --S NL01
	   SET @cSQL =	 N'UPDATE dbo.POD WITH (ROWLOCK)   
					    SET '

      IF ISNULL(@cUDF01,'')<>''
         SET @cSQL = @cSQL + @cUDF01 + ' = @cDoor  '

      IF ISNULL(@cUDF02,'')<>''
         SET @cSQL = @cSQL + CASE WHEN ISNULL(@cUDF01,'')<>'' THEN ',' ELSE  ' 'END + @cUDF02 + ' = @cTruckNo    '

      IF ISNULL(@cUDF03,'')<>''
         SET @cSQL = @cSQL + CASE WHEN ISNULL(@cUDF01,'')<>'' OR ISNULL(@cUDF02,'')<>'' THEN ',' ELSE  ' 'END + @cUDF03 + '= @cTransporter   '

      SET @cSQL = @cSQL +'
						,InvDespatchDate = GetDate()  
						,Status          = ''01''  
					WHERE MbolKey = CASE WHEN @cMBolKey <> '''' THEN @cMBOLKey ELSE MBOLKey END  
						AND LoadKey = CASE WHEN @cLoadKey <> '''' THEN @cLoadKey ELSE LoadKey END  
						AND OrderKey = CASE WHEN @cOrderKey <> '''' THEN @cOrderKey ELSE OrderKey END'

	   SET @cSQLParams = N' @cDoor          NVARCHAR(60) '      
						          + ', @cTruckNo       NVARCHAR(60) ' 
						          + ', @cTransporter   NVARCHAR(60) '
						          + ', @cMbolkey       NVARCHAR(20) '
						          + ', @cLoadkey       NVARCHAR(20) '
						          + ', @cOrderkey      NVARCHAR(20) '

	   EXEC sp_ExecuteSql   @cSQL       
					         , @cSQLParams      
					         , @cDoor           
					         , @cTruckNo    
					         , @cTransporter
					         , @cMbolkey    
					         , @cLoadkey    
					         , @cOrderkey  
	   IF @@ERROR <> 0   
	   BEGIN  
		   SET @nErrNo = 207152  
		   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
		   GOTO ROLLBACKTRAN  
	   END  
	END

	GOTO QUIT  

	RollBackTran:  
	ROLLBACK TRAN ScanToTruckUpdate  
     
      
	Quit:  
	WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
			COMMIT TRAN ScanToTruckUpdate  

END

GO