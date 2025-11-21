SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PostPickAudit_Reset_Confirm                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-12-2022  1.0  yeekung    WMS-21260 Created                        */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_PostPickAudit_Reset_Confirm]
   @nMobile      INT,        
   @nFunc        INT,        
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,       
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cRefNo       NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cLoadKey     NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cID          NVARCHAR( 18), 
   @cTaskdetailKey NVARCHAR( 10),
   @cSKU         NVARCHAR( 20), 
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cWhere      NVARCHAR( 100)
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nRowRef     INT
      -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PostPickAudit_Reset_Confirm -- For rollback or commit only our own transaction

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,
               @cSKU, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile      INT,       ' +
            '@nFunc        INT,       ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,       ' +
            '@nInputKey    INT,       '     +
            '@cStorerKey   NVARCHAR( 15), ' +
            '@cRefNo       NVARCHAR( 10), ' +
            '@cPickSlipNo  NVARCHAR( 10), ' +
            '@cLoadKey     NVARCHAR( 10), ' +
            '@cOrderKey    NVARCHAR( 10), ' +
            '@cDropID      NVARCHAR( 20), ' +
            '@cID          NVARCHAR( 18), ' +
            '@cTaskdetailKey NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@cOption      NVARCHAR( 1),  ' +
            '@nErrNo       INT OUTPUT,  ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,@cID,@cTaskdetailKey,
            @cSKU, '', @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO ROLLBACKTRAN
      END
   END
  

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   ELSE
   BEGIN
      -- SKU
      IF @cSKU <> '' AND @cSKU IS NOT NULL
         SET @cWhere = @cWhere + ' SKU = N''' + @cSKU + ''' AND '

      -- Storer
      SET @cWhere = @cWhere + ' StorerKey = N''' + @cStorerKey + ''' AND '

      -- RefNo
      IF @cRefNo <> '' AND @cRefNo IS NOT NULL
         SET @cWhere = @cWhere + ' RefKey = N''' + @cRefNo + ''''

      -- PickSlipNo
      IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
         SET @cWhere = @cWhere + ' PickSlipNo = N''' + @cPickSlipNo + ''''

      -- LoadKey
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
         SET @cWhere = @cWhere + ' LoadKey = N''' + @cLoadKey + ''''

      -- OrderKey
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
         SET @cWhere = @cWhere + ' OrderKey = N''' + @cOrderKey + ''''

      -- DropID
      IF @cDropID <> '' AND @cDropID IS NOT NULL
         SET @cWhere = @cWhere + ' DropID = N''' + @cDropID + ''''

      -- PalletID
      IF @cID <> '' AND @cID IS NOT NULL
         SET @cWhere = @cWhere + ' ID = N''' + @cID + ''''

      --Taskdetailkey
      IF @cTaskDetailKey <> '' AND @cTaskDetailKey IS NOT NULL
         SET @cWhere = @cWhere + ' Taskdetailkey = N''' + @cTaskDetailKey + ''''

      CREATE TABLE #PPA (RowRef INT)

      SET @cSQL = 'INSERT INTO #PPA SELECT RowRef FROM rdt.rdtPPA WITH (NOLOCK) WHERE ' + @cWhere
      EXEC (@cSQL)

      DECLARE @curPPA CURSOR
      SET @curPPA = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT RowRef
         FROM #PPA
      OPEN @curPPA
      FETCH NEXT FROM @curPPA INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtPPA WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 194901
            SET @cErrMsg = rdt.rdtgetmessage( 73235, @cLangCode, 'DSP') --Fail DEL PPA
            CLOSE @curPPA
            DEALLOCATE @curPPA
            GOTO ROLLBACKTRAN
         END
         FETCH NEXT FROM @curPPA INTO @nRowRef
      END
      CLOSE @curPPA
      DEALLOCATE @curPPA

      GOTO QUIT
   END

   GOTO QUIT

-- Handling transaction
ROLLBACKTRAN:
   ROLLBACK TRAN rdt_PostPickAudit_Reset_Confirm

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO