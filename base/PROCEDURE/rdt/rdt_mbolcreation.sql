SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_MbolCreation                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate orders into MBOL, MBOLDetail                             */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-07-27   1.0  James      WMS-17484 Created                             */
/* 2022-08-03   1.1  James      WMS-20213 Add custom lookup field (james01)   */
/* 2022-10-05   1.2  YeeKung    WMS-20491 Add eventlog (yeekung01)            */
/* 2022-12-15   1.3  James      WMS-21350 Create mbol with header (james02)   */
/* 2023-03-27   1.4  James      WMS-22063 Add orders status check (james03)   */
/*                              Add Update packinfo into mboldetail           */
/* 2023-09-06   1.5  James      WMS-23500 Remove hardcoded remark (james04)   */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_MbolCreation](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cOrderKey    NVARCHAR( 10)
   ,@cLoadKey     NVARCHAR( 10)
   ,@cRefNo1      NVARCHAR( 20)
   ,@cRefNo2      NVARCHAR( 20)
   ,@cRefNo3      NVARCHAR( 20)
   ,@tMbolCreate  VariableTable READONLY
   ,@cMBOLKey     NVARCHAR( 10)  OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cMbolCreateSP  NVARCHAR( 20)

   -- Get storer config
   SET @cMbolCreateSP = rdt.RDTGetConfig( @nFunc, 'MbolCreateSP', @cStorerKey)

   /***********************************************************************************************
                                              Custom create 
   ***********************************************************************************************/
   -- Lookup by SP
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMbolCreateSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cMbolCreateSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cOrderKey, ' +
         ' @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tMbolCreate, ' + 
         ' @cMBOLKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
      SET @cSQLParam =
         ' @nMobile      INT,           ' +
         ' @nFunc        INT,           ' +
         ' @cLangCode    NVARCHAR( 3),  ' +
         ' @nStep        INT,           ' +
         ' @nInputKey    INT,           ' +
         ' @cFacility    NVARCHAR( 5),  ' +
         ' @cStorerKey   NVARCHAR( 15), ' +
         ' @cOrderKey    NVARCHAR( 10), ' +
         ' @cLoadKey     NVARCHAR( 10), ' +
         ' @cRefNo1      NVARCHAR( 20), ' +
         ' @cRefNo2      NVARCHAR( 20), ' +
         ' @cRefNo3      NVARCHAR( 20), ' +
         ' @tMbolCreate  VariableTable READONLY, ' +
         ' @cMBOLKey     NVARCHAR( 10)  OUTPUT, ' +
         ' @nErrNo       INT            OUTPUT, ' +
         ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cOrderKey, 
         @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tMbolCreate, 
         @cMBOLKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit_SP
   END
   
   /***********************************************************************************************
                                             Standard create
   ***********************************************************************************************/
   DECLARE @nTranCount  INT
   DECLARE @nSuccess    INT
   DECLARE @nExists     INT
   DECLARE @curMBOLDTL  CURSOR
   DECLARE @cOUTOrderKey   NVARCHAR( 10)
   DECLARE @cOUTLoadKey    NVARCHAR( 10)
   DECLARE @cOUTExternOrderKey    NVARCHAR( 50)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cRefNoLookupColumn   NVARCHAR( 20)
   DECLARE @cMbolCriteria  NVARCHAR( 20)
   DECLARE @cRefnoLabel1   NVARCHAR( 20)
   DECLARE @cRefnoLabel2   NVARCHAR( 20)
   DECLARE @cRefnoLabel3   NVARCHAR( 20)
   DECLARE @cDATA_TYPE     NVARCHAR( 20)
   DECLARE @cSQLSelect     NVARCHAR( MAX)
   DECLARE @cSQLWhere      NVARCHAR( MAX)
   DECLARE @cSQLExists     NVARCHAR( MAX)
   DECLARE @CColumnName    NVARCHAR( 20)
   DECLARE @nCnt           INT = 1
   DECLARE @cOperator      NVARCHAR( 10)
   DECLARE @curCondition   CURSOR
   DECLARE @cValue         NVARCHAR( 30)
   DECLARE @cSQLCondition  NVARCHAR( MAX)
   DECLARE @nOrderAdded    INT = 0
   DECLARE @ndebug         INT = 0
   DECLARE @cMbolCapturePackInfo NVARCHAR( 1)
   DECLARE @fWeight        FLOAT = 0
   DECLARE @fCube          FLOAT = 0
   DECLARE @nUseSequence   INT
   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @cCartonType    NVARCHAR( 10)
   DECLARE @curUpdMBOLDTL  CURSOR
   DECLARE @curPackInfo    CURSOR
   DECLARE @nCartonNo      INT
   DECLARE @cNotCheckOrdStatus  NVARCHAR( 1) 
   
   DECLARE 
      @nCtnCnt1 INT = 0, 
      @nCtnCnt2 INT = 0, 
      @nCtnCnt3 INT = 0, 
      @nCtnCnt4 INT = 0, 
      @nCtnCnt5 INT = 0, 
      @cUDF01   NVARCHAR(20) = '', 
      @cUDF02   NVARCHAR(20) = '', 
      @cUDF03   NVARCHAR(20) = '', 
      @cUDF04   NVARCHAR(20) = '', 
      @cUDF05   NVARCHAR(20) = '', 
      @cUDF09   NVARCHAR(10) = '', 
      @cUDF10   NVARCHAR(10) = ''

   DECLARE @tMBOLDetail TABLE
   (
      Seq            INT IDENTITY(1,1) NOT NULL,
      MBOLKey        NVARCHAR( 10),
      OrderKey       NVARCHAR( 10),
      CtnCnt1        INT,
      CtnCnt2        INT,
      CtnCnt3        INT,
      CtnCnt4        INT,
      CtnCnt5        INT,
      UserDefine01   NVARCHAR( 20),
      UserDefine02   NVARCHAR( 20),
      UserDefine03   NVARCHAR( 20),
      UserDefine04   NVARCHAR( 20),
      UserDefine05   NVARCHAR( 20),
      UserDefine09   NVARCHAR( 20),
      UserDefine10   NVARCHAR( 20),
      [Cube]         FLOAT,
      [Weight]       FLOAT
   )

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cMbolCapturePackInfo = rdt.rdtGetConfig( @nFunc, 'MbolCapturePackInfo', @cStorerKey)

   SET @cMbolCriteria = rdt.rdtGetConfig( @nFunc, 'MbolCriteria', @cStorerKey)
   IF @cMbolCriteria = '0'
      SET @cMbolCriteria = ''

   SET @cNotCheckOrdStatus = rdt.rdtGetConfig( @nFunc, 'NotCheckOrdStatus', @cStorerKey) 
      
   IF @cMbolCriteria <> ''
   BEGIN
   	DECLARE @curMBOLRule CURSOR
   	SET @curMBOLRule = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   	SELECT UDF01
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = @cMbolCriteria
      AND   StorerKey = @cStorerKey
      AND   code2 = @cFacility
   	ORDER BY Code
      OPEN @curMBOLRule
      FETCH NEXT FROM @curMBOLRule INTO @CColumnName
      WHILE @@FETCH_STATUS = 0
      BEGIN
      	IF @nCnt = 1
      	   SET @cRefnoLabel1 = @CColumnName

      	IF @nCnt = 2
      	   SET @cRefnoLabel2 = @CColumnName

      	IF @nCnt = 3
      	   SET @cRefnoLabel3 = @CColumnName
      	   
         SET @nCnt = @nCnt + 1      	   
      	FETCH NEXT FROM @curMBOLRule INTO @CColumnName
      END
   END
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN MbolCreation -- For rollback or commit only our own transaction
   
   IF @cOrderKey <> '' OR @cLoadKey <> ''
   BEGIN
      SET @nExists = 0
      SET @cSQLSelect = 
         ' SELECT @nExists = COUNT( 1) FROM dbo.ORDERS O WITH (NOLOCK) '  
      IF @cOrderKey <> ''
         SET @cSQLWhere = ' WHERE O.OrderKey = @cOrderKey ' 
      IF @cLoadKey <> ''
         SET @cSQLWhere = ' WHERE O.LoadKey = @cLoadKey ' 

      IF @cMBOLKey = ''
         SET @cSQLExists = +  ' AND EXISTS ( SELECT 1 
                                FROM dbo.MBOLDetail MD WITH (NOLOCK) 
                                WHERE O.OrderKey = MD.OrderKey)'
      ELSE
         SET @cSQLExists = +  ' AND O.MBOLKey = @cMBOLKey ' 

      SET @cSQL = @cSQLSelect + @cSQLWhere + @cSQLExists
   
      SET @cSQLParam = 
         '@cOrderKey    NVARCHAR( 10), ' +  
         '@cLoadKey     NVARCHAR( 10), ' +  
         '@cMBOLKey     NVARCHAR( 20), ' + 
         '@cRefNo1      NVARCHAR( 20), ' +
         '@cRefNo2      NVARCHAR( 20), ' +
         '@cRefNo3      NVARCHAR( 20), ' +
         '@nExists      INT   OUTPUT '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @cOrderKey, @cLoadKey, @cMBOLKey, @cRefNo1, @cRefNo2, @cRefNo3, @nExists OUTPUT

      IF @nExists > 0
      BEGIN
         SET @nErrNo = 172151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orders in mbol
         GOTO RollBackTran
      END
   END

   -- Create MBOL header only (james02)
   -- Sometime user wanna create header only and use Excel loader to upload details
   IF @cMBOLKey = 'NOORDER'
   BEGIN
      SET @nSuccess = 1
      EXECUTE dbo.nspg_getkey
         'MBOL'
         , 10
         , @cMBOLKey    OUTPUT
         , @nSuccess    OUTPUT
         , @nErrNo      OUTPUT
         , @cErrMsg     OUTPUT

      IF @nSuccess <> 1
      BEGIN
         SET @nErrNo = 172157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
         GOTO RollBackTran
      END

      INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks, 
                        AddWho, AddDate, EditWho, EditDate) VALUES 
                        (@cMBOLKey, '', @cFacility, '0', '', 
                        LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(),     
                        LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 172158
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOL Err
         GOTO RollBackTran
      END

      COMMIT TRAN MbolCreation -- Only commit change made here
      GOTO Quit
   END

   SET @cSQL = ''
   SET @cSQLSelect = ''
   SET @cSQLWhere = ''
   SET @cSQLExists = ''
   
   SET @cSQLSelect = 
      ' SELECT OrderKey, LoadKey, ExternOrderKey FROM dbo.ORDERS O WITH (NOLOCK) '  

   SET @cSQLWhere = ' WHERE O.StorerKey = @cStorerKey '
   SET @cSQLWhere = @cSQLWhere + ' AND O.Status < ''9'' '
   SET @cSQLWhere = @cSQLWhere + ' AND O.Facility = @cFacility '
   
   IF @cOrderKey <> ''
      SET @cSQLWhere = @cSQLWhere + ' AND O.OrderKey = @cOrderKey ' 
   IF @cLoadKey <> ''
      SET @cSQLWhere = @cSQLWhere + ' AND O.LoadKey = @cLoadKey ' 
   
   IF @cMbolCriteria <> '' 
   BEGIN
      IF @cRefno1 <> ''
      BEGIN
         SELECT @cDATA_TYPE = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERS' 
         AND COLUMN_NAME = @cRefnoLabel1

         IF @cDATA_TYPE = 'NVARCHAR'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel1 + ' = ' +  '@cRefNo1 '
         ELSE IF @cDATA_TYPE = 'INT'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel1 + ' = ' +  'CAST( @cRefNo1 AS INT) '
         ELSE 
         	SET @cSQLWhere = @cSQLWhere + ' AND CONVERT( NVARCHAR( 8), CAST( O.' + @cRefnoLabel1 + ' AS DATE), 112)' + ' = ' +  '@cRefNo1 '
      END
         	
      IF @cRefno2 <> ''
      BEGIN
         SELECT @cDATA_TYPE = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERS' 
         AND COLUMN_NAME = @cRefnoLabel2

         IF @cDATA_TYPE = 'NVARCHAR'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel2 + ' = ' +  '@cRefNo2 '
         ELSE IF @cDATA_TYPE = 'INT'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel2 + ' = ' +  'CAST( @cRefNo2 AS INT) '
         ELSE 
         	SET @cSQLWhere = @cSQLWhere + ' AND CONVERT( NVARCHAR( 8), CAST( O.' + @cRefnoLabel2 + ' AS DATE), 112)' + ' = ' +  '@cRefNo2 '
      END

      IF @cRefno3 <> ''
      BEGIN
         SELECT @cDATA_TYPE = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'ORDERS' 
         AND COLUMN_NAME = @cRefnoLabel3

         IF @cDATA_TYPE = 'NVARCHAR'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel3 + ' = ' +  '@cRefNo3 '
         ELSE IF @cDATA_TYPE = 'INT'
            SET @cSQLWhere = @cSQLWhere + ' AND O.' + @cRefnoLabel3 + ' = ' +  'CAST( @cRefNo3 AS INT) '
         ELSE 
         	SET @cSQLWhere = @cSQLWhere + ' AND CONVERT( NVARCHAR( 8), CAST( O.' + @cRefnoLabel3 + ' AS DATE), 112)' + ' = ' +  '@cRefNo3 '
      END
   END

   SET @cSQLCondition = ''
   SET @cColumnName = ''
   SET @cOperator = ''
   SET @cValue = ''
   
   SET @curCondition = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT UDF01, UDF02, UDF03
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'BuildMBCon' 
   AND   Storerkey = @cStorerKey
   AND   code2 = @cFacility
   OPEN @curCondition
   FETCH NEXT FROM @curCondition INTO @cColumnName, @cOperator, @cValue
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @cDATA_TYPE = DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = 'ORDERS' 
      AND COLUMN_NAME = @cColumnName

      IF @@ROWCOUNT = 0
         BREAK

      IF @cDATA_TYPE = 'NVARCHAR'
         SET @cSQLCondition = @cSQLCondition + ' AND O.' + @cColumnName + @cOperator + '''' + @cValue + ''''
      ELSE IF @cDATA_TYPE = 'INT'
         SET @cSQLCondition = @cSQLCondition + ' AND O.' + @cColumnName + @cOperator + CAST( @cValue AS INT)
      ELSE 
         SET @cSQLCondition = @cSQLCondition + ' AND CONVERT( NVARCHAR( 8), CAST( O.' + @cColumnName + ' AS DATE), 112)' + @cOperator + '''' + @cValue + ''''

   	FETCH NEXT FROM @curCondition INTO @cColumnName, @cOperator, @cValue
   END 

   SET @cSQLExists = +  ' AND NOT EXISTS ( SELECT 1 
                          FROM dbo.MBOLDetail MD WITH (NOLOCK) 
                          WHERE O.OrderKey = MD.OrderKey)'

   SET @cSQL = @cSQLSelect + @cSQLWhere + @cSQLCondition + @cSQLExists
   SET @cSQL = @cSQL +  ' GROUP BY OrderKey, LoadKey, ExternOrderKey'
   SET @cSQL = @cSQL +  ' ORDER BY OrderKey'

   IF @ndebug > 0
   BEGIN
      PRINT @cSQL
   END
   
   -- Open cursor  
   SET @cSQL =   
      ' SET @curMBOLDTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +   
       @cSQL +   
      ' OPEN @curMBOLDTL '   

   SET @cSQLParam = 
      '@curMBOLDTL   CURSOR OUTPUT, ' + 
      '@cStorerKey   NVARCHAR( 15), ' +
      '@cOrderKey    NVARCHAR( 10), ' +  
      '@cLoadKey     NVARCHAR( 10), ' +  
      '@cRefNo1      NVARCHAR( 20), ' +
      '@cRefNo2      NVARCHAR( 20), ' +
      '@cRefNo3      NVARCHAR( 20), ' + 
      '@cFacility    NVARCHAR( 5)   '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
      @curMBOLDTL OUTPUT, @cStorerKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @cFacility

   FETCH NEXT FROM @curMBOLDTL INTO @cOUTOrderKey, @cOUTLoadKey, @cOUTExternOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
    IF @cNotCheckOrdStatus = '0'  
    BEGIN  
       IF EXISTS ( SELECT 1   
                   FROM dbo.ORDERS WITH (NOLOCK)  
                   WHERE OrderKey = @cOUTOrderKey  
                   AND   [Status] <> '5')  
         BEGIN  
            SET @nErrNo = 172159  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORD X PICKED  
            GOTO RollBackTran  
         END  
    END  

      IF @cMBOLKey = ''
      BEGIN
         SET @nSuccess = 1
         EXECUTE dbo.nspg_getkey
            'MBOL'
            , 10
            , @cMBOLKey    OUTPUT
            , @nSuccess    OUTPUT
            , @nErrNo      OUTPUT
            , @cErrMsg     OUTPUT

         IF @nSuccess <> 1
         BEGIN
            SET @nErrNo = 172152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO RollBackTran
         END

      INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks, 
                        AddWho, AddDate, EditWho, EditDate) VALUES 
                        (@cMBOLKey, '', @cFacility, '0', '', 
                        LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(),     
                        LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 172153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOL Err
            GOTO RollBackTran
         END
      END
   
      IF @cMbolCapturePackInfo = '1'
      BEGIN
         SELECT @cPickSlipNo = PickSlipNo 
         FROM dbo.PackHeader WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   OrderKey = @cOUTOrderKey 
         
         SET @curPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT CartonNo, CartonType, [Weight], [Cube]
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         ORDER BY 1
         OPEN @curPackInfo
         FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cCartonType, @fWeight, @fCube         
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get carton type info
            SELECT @nUseSequence = UseSequence
            FROM dbo.Cartonization C WITH (NOLOCK)
            JOIN dbo.Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
            WHERE S.StorerKey = @cStorerKey
            AND   C.CartonType = @cCartonType

            SELECT @nCtnCnt1 = 0, @nCtnCnt2 = 0, @nCtnCnt3 = 0, @nCtnCnt4 = 0, @nCtnCnt5 = 0 
            SELECT @cUDF01 = '', @cUDF02 = '', @cUDF03 = '', @cUDF04 = '', @cUDF05 = '', @cUDF09 = '', @cUDF10 = ''
      
            IF @nUseSequence = 1  SET @nCtnCnt1 = 1 ELSE
            IF @nUseSequence = 2  SET @nCtnCnt2 = 1 ELSE
            IF @nUseSequence = 3  SET @nCtnCnt3 = 1 ELSE
            IF @nUseSequence = 4  SET @nCtnCnt4 = 1 ELSE
            IF @nUseSequence = 5  SET @nCtnCnt5 = 1 ELSE
            IF @nUseSequence = 6  SET @cUDF01 = '1' ELSE
            IF @nUseSequence = 7  SET @cUDF02 = '1' ELSE
            IF @nUseSequence = 8  SET @cUDF03 = '1' ELSE
            IF @nUseSequence = 9  SET @cUDF04 = '1' ELSE
            IF @nUseSequence = 10 SET @cUDF05 = '1' ELSE
            IF @nUseSequence = 11 SET @cUDF09 = '1' ELSE
            IF @nUseSequence = 12 SET @cUDF10 = '1'

            IF NOT EXISTS ( SELECT 1 FROM @tMBOLDetail WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOUTOrderKey)
            BEGIN
         	   INSERT INTO @tMBOLDetail (MBOLKey, OrderKey, CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5, 
         	   UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10, 
         	   [Cube], [Weight]) VALUES
         	   (@cMBOLKey, @cOUTOrderKey, 
         	   CASE WHEN @nUseSequence = 1  THEN @nCtnCnt1 ELSE 0 END,
               CASE WHEN @nUseSequence = 2  THEN @nCtnCnt2 ELSE 0 END,
               CASE WHEN @nUseSequence = 3  THEN @nCtnCnt3 ELSE 0 END,
               CASE WHEN @nUseSequence = 4  THEN @nCtnCnt4 ELSE 0 END,
               CASE WHEN @nUseSequence = 5  THEN @nCtnCnt5 ELSE 0 END,
               CASE WHEN @nUseSequence = 6  THEN @cUDF01 ELSE '' END,
               CASE WHEN @nUseSequence = 7  THEN @cUDF02 ELSE '' END,
               CASE WHEN @nUseSequence = 8  THEN @cUDF03 ELSE '' END,
               CASE WHEN @nUseSequence = 9  THEN @cUDF04 ELSE '' END,
               CASE WHEN @nUseSequence = 10 THEN @cUDF05 ELSE '' END,
               CASE WHEN @nUseSequence = 11 THEN @cUDF09 ELSE '' END,
               CASE WHEN @nUseSequence = 12 THEN @cUDF10 ELSE '' END,
               CASE WHEN @fCube > 0 THEN @fCube ELSE 0 END,
               CASE WHEN @fWeight > 0 THEN @fWeight ELSE 0 END)
            END
            ELSE
            BEGIN
               UPDATE @tMBOLDetail SET
                   CtnCnt1      = CASE WHEN @nUseSequence = 1  THEN CtnCnt1 + 1 ELSE CtnCnt1 END
                  ,CtnCnt2      = CASE WHEN @nUseSequence = 2  THEN CtnCnt2 + 1 ELSE CtnCnt2 END
                  ,CtnCnt3      = CASE WHEN @nUseSequence = 3  THEN CtnCnt3 + 1 ELSE CtnCnt3 END
                  ,CtnCnt4      = CASE WHEN @nUseSequence = 4  THEN CtnCnt4 + 1 ELSE CtnCnt4 END
                  ,CtnCnt5      = CASE WHEN @nUseSequence = 5  THEN CtnCnt5 + 1 ELSE CtnCnt5 END
                  ,UserDefine01 = CASE WHEN @nUseSequence = 6  THEN CAST( UserDefine01 AS INT) + 1 ELSE UserDefine01 END
                  ,UserDefine02 = CASE WHEN @nUseSequence = 7  THEN CAST( UserDefine02 AS INT) + 1 ELSE UserDefine02 END
                  ,UserDefine03 = CASE WHEN @nUseSequence = 8  THEN CAST( UserDefine03 AS INT) + 1 ELSE UserDefine03 END
                  ,UserDefine04 = CASE WHEN @nUseSequence = 9  THEN CAST( UserDefine04 AS INT) + 1 ELSE UserDefine04 END
                  ,UserDefine05 = CASE WHEN @nUseSequence = 10 THEN CAST( UserDefine05 AS INT) + 1 ELSE UserDefine05 END
                  ,UserDefine09 = CASE WHEN @nUseSequence = 11 THEN CAST( UserDefine09 AS INT) + 1 ELSE UserDefine09 END
                  ,UserDefine10 = CASE WHEN @nUseSequence = 12 THEN CAST( UserDefine10 AS INT) + 1 ELSE UserDefine10 END
                  ,[Cube]         = CASE WHEN @fCube > 0 THEN [CUBE] + @fCube ELSE [Cube] END
                  ,[Weight]       = CASE WHEN @fWeight > 0 THEN [WEIGHT] + @fWeight ELSE [Weight] END
               WHERE MBOLKey = @cMBOLKey
               AND   OrderKey = @cOUTOrderKey
            END

            FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cCartonType, @fWeight, @fCube
         END
         CLOSE @curPackInfo
         DEALLOCATE @curPackInfo

         SELECT 
            @nCtnCnt1 = CtnCnt1,
            @nCtnCnt1 = CtnCnt2,
            @nCtnCnt1 = CtnCnt3,
            @nCtnCnt1 = CtnCnt4,
            @nCtnCnt1 = CtnCnt5,
            @cUDF01   = UserDefine01,
            @cUDF02   = UserDefine02,
            @cUDF03   = UserDefine03,
            @cUDF04   = UserDefine04,
            @cUDF05   = UserDefine05,
            @cUDF09   = UserDefine09,
            @cUDF10   = UserDefine10,
            @fCube    = [Cube],
            @fWeight  = [Weight] 
         FROM @tMBOLDetail
         WHERE MBOLKey = @cMBOLKey
         AND   OrderKey = @cOUTOrderKey
      END

      INSERT INTO dbo.MBOLDetail 
      (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, ExternOrderKey, 
      CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5,
      UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
      UserDefine09, UserDefine10, [Cube], [Weight],
      AddWho, AddDate, EditWho, EditDate) 
      VALUES
      (@cMBOLKey, '00000', @cOUTOrderKey, @cOUTLoadKey, @cOUTExternOrderKey, 
      @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5,
      @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, 
      @cUDF09, @cUDF10, @fCube, @fWeight,
      @cUserName, GETDATE(), @cUserName, GETDATE())
         
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 172154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins MBOLDtl Err
         GOTO RollBackTran
      END

      SET @nOrderAdded = @nOrderAdded + 1

      FETCH NEXT FROM @curMBOLDTL INTO @cOUTOrderKey, @cOUTLoadKey, @cOUTExternOrderKey
   END

   IF @nOrderAdded = 0
   BEGIN
      SET @nErrNo = 172155
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO ORDERS ADD
      SET @cMBOLKey = ''
      GOTO RollBackTran
   END

   EXEC RDT.rdt_STD_EventLog    --(yeekung01)
      @cActionType   = '4', 
      @cUserID       = @cUserName,    
      @nMobileNo     = @nMobile,    
      @nFunctionID   = @nFunc,    
      @cFacility     = @cFacility,    
      @cStorerKey    = @cStorerKey,    
      @cTrackingno   = @cRefNo1,    
      @cOrderKey     = @cOUTOrderKey,    
      @cLoadkey      = @cOUTLoadKey,    
      @cMbolkey      = @cMBOLKey   

   COMMIT TRAN MbolCreation -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN MbolCreation -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
Quit_SP:
END

GO