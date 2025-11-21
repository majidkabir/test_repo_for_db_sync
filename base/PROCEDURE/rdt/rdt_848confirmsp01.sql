SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_848confirmSP01                                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-12-2022  1.0  yeekung    WMS-21260 Created                        */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_848confirmSP01]
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
   SAVE TRAN rdt_848confirmSP01 -- For rollback or commit only our own transaction
   
   CREATE TABLE #PPA (RowRef INT)

   SET @cSQL = 'INSERT INTO #PPA' 


   -- PickSlipNo
   IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
     -- SKU
      IF @cSKU <> '' AND @cSKU IS NOT NULL
         SET @cWhere = @cWhere + 'PD.SKU = N''' + @cSKU + ''' AND '

      -- Storer
      SET @cWhere = @cWhere + 'PD.StorerKey = N''' + @cStorerKey + ''' AND '

      SET @cWhere = @cWhere + ' PH.pickheaderkey = N''' + @cPickSlipNo + ''''

      SET @cSQL = @cSQL+ ' SELECT RowRef FROM rdt.rdtPPA PPA WITH (NOLOCK) 
                           JOIN pickdetail PD (NOLOCK) ON PPA.ID=PD.ID AND PPA.SKU=PD.SKU
                           JOIN orders O (NOLOCK) ON PD.orderkey=O.orderkey
                           JOIN pickheader PH (NOLOCK) ON PH.ExternOrderKey=o.LoadKey  
                           WHERE '  
                           +@cWhere
   END
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

       SET @cSQL = @cSQL+ ' SELECT RowRef FROM rdt.rdtPPA WITH (NOLOCK) WHERE '  +@cWhere
   END

   EXEC (@cSQL)

   -- Delete PPA
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
         SET @nErrNo = 194201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail DEL PPA
         CLOSE @curPPA
         DEALLOCATE @curPPA
         GOTO ROLLBACKTRAN
      END
      FETCH NEXT FROM @curPPA INTO @nRowRef
   END
   CLOSE @curPPA
   DEALLOCATE @curPPA

   GOTO QUIT

-- Handling transaction
ROLLBACKTRAN:
   ROLLBACK TRAN rdt_848confirmSP01

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_848confirmSP01

END

GO