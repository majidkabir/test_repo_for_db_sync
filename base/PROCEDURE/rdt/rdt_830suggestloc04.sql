SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_830SuggestLOC04                                          */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest LOC, lock by pickzone and aisle                              */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2022-11-07  1.0  Ung         WMS-21032 Created                                */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_830SuggestLOC04]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cSuggLOC         NVARCHAR( 10) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLCommonFrom    NVARCHAR( MAX)
   DECLARE @cSQLCommonWhere   NVARCHAR( MAX)
   DECLARE @cSQLCommonParam   NVARCHAR( MAX)

   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLoadKey          NVARCHAR( 10)
   DECLARE @cZone             NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo


   /***********************************************************************************************
                                             Built common SQL
   ***********************************************************************************************/
   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' 
      SET @cSQLCommonWhere = 
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus ' 
   END
        
   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' 
      SET @cSQLCommonWhere = 
         ' WHERE PD.OrderKey = @cOrderKey ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus '
   END
      
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) '
      SET @cSQLCommonWhere = 
         ' WHERE LPD.LoadKey = @cLoadKey ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' '
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SET @cSQLCommonFrom = 
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) '
      SET @cSQLCommonWhere = 
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' + 
            ' AND PD.QTY > 0 ' + 
            ' AND PD.Status <> ''4'' ' + 
            ' AND PD.Status < @cPickConfirmStatus '
   END

   SET @cSQLCommonParam = 
      '@cPickSlipNo        NVARCHAR( 10), ' + 
      '@cOrderKey          NVARCHAR( 10), ' + 
      '@cLoadKey           NVARCHAR( 10), ' + 
      '@cPickConfirmStatus NVARCHAR( 1),  ' + 
      '@cLOCAisle          NVARCHAR( 10) = '''', ' + 
      '@cLogicalLOC        NVARCHAR( 18) = '''', ' + 
      '@cLOC               NVARCHAR( 10) = '''', ' + 
      '@cNewSuggLOC        NVARCHAR( 10) = '''' OUTPUT, ' +   
      '@cNewSuggAisle      NVARCHAR( 10) = '''' OUTPUT  '  


   /***********************************************************************************************
                                           Insert rdtPickSKULock
   ***********************************************************************************************/
   IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      SET @cSQL = 
         ' INSERT INTO rdt.rdtPickSKULock (PickSlipNo, PickZone, LOCAisle) ' + 
         ' SELECT @cPickSlipNo, LOC.PickZone, LOC.LOCAisle ' + 
         @cSQLCommonFrom + 
         @cSQLCommonWhere + 
         ' GROUP BY LOC.PickZone, LOC.LOCAisle ' + 
         ' ORDER BY LOC.PickZone, LOC.LOCAisle '

      exec sp_executeSQL @cSQL, @cSQLCommonParam, 
         @cPickSlipNo = @cPickSlipNo, 
         @cOrderKey   = @cOrderKey, 
         @cLoadKey    = @cLoadKey, 
         @cPickConfirmStatus = @cPickConfirmStatus

   END
   
   /***********************************************************************************************
                                             Get suggest LOC
   ***********************************************************************************************/
   DECLARE @cLOCAisle      NVARCHAR( 10) = ''
   DECLARE @cLogicalLOC    NVARCHAR( 18) = ''
   DECLARE @cPickSEQ       NVARCHAR( 4)  = ''
   DECLARE @cNewSuggLOC    NVARCHAR( 10) = ''
   DECLARE @cNewSuggAisle  NVARCHAR( 10) = ''

   -- Get loc info
   IF @cLOC <> ''
      SELECT 
         @cLogicalLOC = ISNULL( LogicalLocation, ''), 
         @cLOCAisle = ISNULL( LOCAisle, '')
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cLOC

   -- Get picker initial sequence, if already picking
   SELECT TOP 1 @cPickSEQ = PickSEQ FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho = SUSER_SNAME()
   
   -- Calc pick seq (initial pick or new picker join)
   IF @cPickSEQ = ''
   BEGIN
      -- Get picker in ASC and DESC sequence
      DECLARE @cPickSEQInASC  INT
      DECLARE @cPickSEQInDESC INT
      SELECT @cPickSEQInASC = COUNT(1) FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '' AND PickSEQ = 'A'
      SELECT @cPickSEQInDESC = COUNT(1) FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '' AND PickSEQ = 'D'
      
      IF @cPickSEQInASC <= @cPickSEQInDESC
         SET @cPickSEQ = 'A'
      ELSE
         SET @cPickSEQ = 'D'
   END
   
   SET @cPickSEQ = CASE WHEN @cPickSEQ = 'A' THEN 'ASC' ELSE 'DESC' END
   
   -- Build get suggest LOC
   SET @cSQL = 
      ' SELECT TOP 1 ' + 
         ' @cNewSuggLOC = LOC.LOC,       ' + 
         ' @cNewSuggAisle = LOC.LOCAisle ' + 
         @cSQLCommonFrom + 
            ' JOIN rdt.rdtPickSKULock L WITH (NOLOCK) ON (LOC.PickZone = L.PickZone AND LOC.LOCAisle = L.LOCAisle AND L.PickSlipNo = @cPickSlipNo) ' + 
         @cSQLCommonWhere + 
              CASE WHEN @cLOC = '' THEN '' ELSE 
                 ' AND CAST( LOC.LOCAisle AS NCHAR( 10)) + CAST( LOC.LogicalLocation AS NCHAR( 18)) + CAST( LOC.LOC AS NCHAR( 10)) ' + 
                       CASE WHEN @cPickSEQ = 'ASC' THEN '>' ELSE '<' END + 
                     ' CAST( @cLOCAisle AS NCHAR( 10)) + CAST( @cLogicalLOC AS NCHAR( 18)) + CAST( @cLOC AS NCHAR( 10)) ' 
              END + 
            ' AND (L.LockWho = '''' ' + 
            ' OR   L.LockWho = SUSER_SNAME())' + 
         CASE WHEN @cPickZone = '' THEN '' ELSE ' AND LOC.PickZone = @cPickZone ' END + 
      ' GROUP BY LOC.LOCAisle, LOC.LogicalLocation, LOC.LOC ' +
      ' ORDER BY ' + 
         '  LOC.LOCAisle ' + @cPickSEQ + 
         ' ,LOC.LogicalLocation ' + @cPickSEQ + 
         ' ,LOC.LOC ' + @cPickSEQ

   WHILE (1=1)
   BEGIN
      -- Get suggest LOC
      EXEC sp_executeSQL @cSQL, @cSQLCommonParam, 
         @cPickSlipNo = @cPickSlipNo, 
         @cOrderKey   = @cOrderKey, 
         @cLoadKey    = @cLoadKey, 
         @cLOCAisle   = @cLOCAisle, 
         @cLogicalLOC = @cLogicalLOC, 
         @cLOC        = @cLOC, 
         @cNewSuggLOC = @cNewSuggLOC OUTPUT, 
         @cNewSuggAisle = @cNewSuggAisle OUTPUT, 
         @cPickConfirmStatus = @cPickConfirmStatus

      -- Found suggest LOC
      IF @cNewSuggLOC <> ''
         BREAK
      ELSE
      BEGIN
         -- Search from begining again
         IF @cLOC <> ''
         BEGIN
            SET @cLOC = ''
            SET @cLogicalLOC = ''
            CONTINUE
         END
         ELSE
         BEGIN
            SET @nErrNo = 193701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
            SET @nErrNo = -1 -- No more task
            BREAK
         END
      END
   END

   IF @cNewSuggLOC <> ''
   BEGIN
      DECLARE @nRowRef INT = 0
      DECLARE @cLockWho NVARCHAR( 128) = ''
      
      -- Get lock aisle info
      IF @cPickZone = ''
         SELECT 
            @nRowRef = RowRef, 
            @cLockWho = LockWho
         FROM rdt.rdtPickSKULock WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND LOCAisle = @cNewSuggAisle
      ELSE
         SELECT 
            @nRowRef = RowRef, 
            @cLockWho = LockWho
         FROM rdt.rdtPickSKULock WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND PickZone = @cPickZone
            AND LOCAisle = @cNewSuggAisle

      -- Check data error
      IF @nRowRef = 0
      BEGIN
         SET @nErrNo = 193702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
         GOTO Quit
      END
      
      -- Check aisle locked by others
      IF @cLockWho NOT IN ('', SUSER_SNAME())
      BEGIN
         SET @nErrNo = 193703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
         GOTO Quit
      END
      
      -- Lock aisle
      IF @cLockWho = ''
      BEGIN
         UPDATE rdt.rdtPickSKULock SET
            PickSEQ = LEFT( @cPickSEQ, 1), 
            LockWho = SUSER_SNAME(), 
            LockDate = GETDATE()
         WHERE RowRef = @nRowRef 
            AND LockWho = ''
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 193704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockAisleFail
            GOTO Quit
         END
      END
         
      SET @cSuggLOC = @cNewSuggLOC
   
   END
   
Quit:

END

GO