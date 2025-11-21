SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PltConsoSSCC_BuildPlt                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: INSERT/UPDATE Pallet & PalletDetail table                   */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate_SSCC                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 23-Mar-2016 1.0  James       SOS357366 - Created                     */
/* 01-Sep-2016 1.1  James       Add process for step 8 (james01)        */
/* 13-May-2020 1.2  James       WMS-5526 Allow non casecnt (james02)    */
/* 13-Oct-2021 1.3  Chermaine   WMS-18008 Add Custom BuildPltSP (cc01)  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PltConsoSSCC_BuildPlt] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @cStorerkey                NVARCHAR( 15), 
   @cFromLOC                  NVARCHAR( 10), 
   @cFromID                   NVARCHAR( 18), 
   @cToID                     NVARCHAR( 18), 
   @cType                     NVARCHAR( 1),  
   @cOption                   NVARCHAR( 1), 
   @cCartonID                 NVARCHAR( 20), 
   @nQTY_Move                 INT,
   @nQTY_Alloc                INT,
   @nQTY_Pick                 INT,
   @cSSCC                     NVARCHAR( 20)  OUTPUT, 
   @nErrNo                    INT            OUTPUT,  
   @cErrMsg                   NVARCHAR( 20)  OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount        INT,
           @nStep             INT,
           @nPD_Qty           INT,
           @nMV_Alloc         INT,
           @nMV_Pick          INT,
           @bSuccess          INT,
           @nCaseID_Qty       INT,
           @nCase_Qty         INT,
           @nDPK_Qty          INT,
           @nPUOM_Div         INT,
           @nBuildNewSSCC     INT,
           @cMoveRefKey       NVARCHAR( 10),
           @cPackUOM3         NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cFacility         NVARCHAR( 5),
           @cPickDetailKey    NVARCHAR( 10),
           @cPalletLineNumber NVARCHAR( 5),
           @cOrderKey         NVARCHAR( 10), 
           @cMBOLKey          NVARCHAR( 10),
           @cSKU              NVARCHAR( 20),
           @cCaseID           NVARCHAR( 20),
           @cNewPickDetailKey NVARCHAR( 10), 
           @cUserDefine02     NVARCHAR( 30), 
           @cItemClass        NVARCHAR( 10),
           @cCounter          NVARCHAR( 25),
           @cToID_MbolKey     NVARCHAR( 10),
           @cFromID_OrderKey  NVARCHAR( 10)
           

   DECLARE @nQty              INT
   DECLARE @cSQL              NVARCHAR(MAX)   --(cc01)
   DECLARE @cSQLParam         NVARCHAR(MAX)   --(cc01)
   DECLARE @cBuildPltSP       NVARCHAR( 20)   --(cc01)
   
   SET @cBuildPltSP = rdt.RDTGetConfig( @nFunc, 'BuildPltSP', @cStorerKey) --(cc01)

   SELECT @nStep = Step, 
          @cFacility = Facility, 
          @cUserName = UserName, 
          @cSKU = V_SKU
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
/***********************************************************************************************
                                          Custom BuildPltSP
***********************************************************************************************/
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cBuildPltSP AND type = 'P')
      BEGIN           
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cBuildPltSP) +
            ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFromLOC, @cFromID, @cToID, @cType, ' +
            ' @cOption, @cCartonID, @nQTY_Move, @nQTY_Alloc, @nQTY_Pick, ' +
            ' @cSSCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         
         SET @cSQLParam =
            ' @nMobile        INT,            ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @cStorerkey     NVARCHAR( 15), ' +
            ' @cFromLOC       NVARCHAR( 10), ' +
            ' @cFromID        NVARCHAR( 18), ' +
            ' @cToID          NVARCHAR( 18), ' +
            ' @cType          NVARCHAR( 1),  ' +
            ' @cOption        NVARCHAR( 1),  ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @nQTY_Move      INT,           ' +
            ' @nQTY_Alloc     INT,           ' +
            ' @nQTY_Pick      INT,           ' +
            ' @cSSCC          NVARCHAR( 20)  OUTPUT, ' +
            ' @nErrNo         INT            OUTPUT,  ' +
            ' @cErrMsg        NVARCHAR( 20)  OUTPUT   '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFromLOC, @cFromID, @cToID, @cType,
            @cOption, @cCartonID, @nQTY_Move, @nQTY_Alloc, @nQTY_Pick,
            @cSSCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
/***********************************************************************************************
                                             Standard confirmSP
***********************************************************************************************/
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PltConsoSSCC_BuildPlt

   -- Pallet info. Need determine option 1 or 3. Then built pallet
   IF @nStep IN ( 2, 8) -- (james01)
   BEGIN
      IF @nStep = 8     -- (james01)
         SET @cOption = '3'

      IF @cOption IN ('1', '3')
      BEGIN
         SET @cSSCC = ''
         -- Get SSCC
         SELECT TOP 1 @cSSCC = LA.Lottable09, 
                      @cSKU = LLI.SKU
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.ID = @cFromID 
         AND   LLI.Qty > 0
         AND   LOC.Facility = @cFacility
         --AND   LOC.LocationCategory = 'STAGING'
      END

      IF @cOption = '3'
      BEGIN
         SELECT @cItemClass = ItemClass
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   SKU = @cSKU

         SET @nBuildNewSSCC = 0

         IF ISNULL( @cItemClass, '') <> '001'
            SET @nBuildNewSSCC = 1
         ELSE  -- Itemclass = 001
         BEGIN
            IF LEN( RTRIM( @cSSCC)) < 10
               SET @nBuildNewSSCC = 1
         END

         IF @nBuildNewSSCC = 1
         BEGIN
            EXECUTE nspg_getkey
               @KeyName       = 'MHAPSSCCP' ,
               @fieldlength   = 17,    
               @keystring     = @cCounter    Output,
               @b_success     = @bSuccess    Output,
               @n_err         = @nErrNo      Output,
               @c_errmsg      = @cErrMsg     Output,
               @b_resultset   = 0,
               @n_batch       = 1

            IF @nErrNo <> 0 OR @bSuccess <> 1
            BEGIN
               SET @nErrNo = 98376
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get sscc fail
               GOTO RollBackTran
            END

            SET @cSSCC = 'P' + @cCounter
         END

         IF ISNULL( @cSSCC, '') = ''
         BEGIN
            SET @nErrNo = 98351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC req
            GOTO RollBackTran
         END

         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                     WHERE PalletKey = @cSSCC
                     AND   StorerKey = @cStorerKey)
         BEGIN

            SET @nErrNo = 98375
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt consoled
            GOTO RollBackTran
         END

         SELECT TOP 1 @cFromID_OrderKey = UserDefine04
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cFromID
         AND   [Status] < '9'
         ORDER BY EditDate DESC  -- latest scanned

         IF ISNULL( @cFromID_OrderKey, '') <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   ID = @cFromID
                        AND   OrderKey = @cFromID_OrderKey
                        AND   [Status] < '9')
            BEGIN
               SET @nErrNo = 98380
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet consoled
               GOTO RollBackTran
            END
         END

         -- Insert Pallet info
         INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cSSCC, @cStorerKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 98352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
            GOTO RollBackTran
         END

         IF ISNULL( @cFromID, '') = ''
         BEGIN
            SET @nErrNo = 98381
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv asrs plt
            GOTO RollBackTran
         END

         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.PickDetailKey, ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cFromID 
         AND   PD.Status < '9'
         AND   LOC.Facility = @cFacility
         --AND   LOC.LocationCategory = 'STAGING'
         GROUP BY PickDetailKey
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                            WHERE PalletKey = @cSSCC
                            AND   UserDefine02 = @cPickDetailKey)
            BEGIN
               SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PalletDetail WITH (NOLOCK)
               WHERE PalletKey = @cSSCC

               SELECT @cOrderKey = O.OrderKey,
                      @cMBOLKey = O.MBOLKey,
                      @cSKU = PD.SKU
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
               WHERE PickDetailKey = @cPickDetailKey

               INSERT INTO dbo.PalletDetail 
               (PalletKey, PalletLineNumber, StorerKey, Sku, Qty, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05) 
               VALUES
               (@cSSCC, @cPalletLineNumber, @cStorerKey, @cSKU, @nPD_Qty, @cFromID, @cPickDetailKey, @cMBOLKey, @cOrderKey, @cFromID)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SELECT @cOrderKey = O.OrderKey,
                      @cMBOLKey = O.MBOLKey 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
               WHERE PickDetailKey = @cPickDetailKey

               UPDATE dbo.PalletDetail WITH (ROWLOCK)
                  SET Qty = Qty + @nPD_Qty,
                      UserDefine01 = @cFromID,
                      UserDefine03 = @cMBOLKey,
                      UserDefine04 = @cOrderKey
               WHERE PalletKey = @cSSCC
               AND   UserDefine02 = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98354
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltd err
                  GOTO RollBackTran
               END
            END
            FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END   -- IF @cOption IN ('1', '3')
   END   -- IF @nStep = 2

   -- Insert To ID (Shipper pallet) case detail into pallet detail 
   IF @nStep = 4
   BEGIN
      -- Insert record into the log table
      IF @cType = 'I'
      BEGIN
         SELECT 
            @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
         FROM dbo.SKU S WITH (NOLOCK) 
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

         WHILE @nQTY_Move > 0
         BEGIN
            -- (james02)
            IF @nQTY_Move < @nPUOM_Div
               SET @nQty = @nQTY_Move
            ELSE
               SET @nQty = @nPUOM_Div
            
            INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromLot, FromID, QtyMove, PAQty, CaseID, BOMSKU, TaskdetailKey, UserKey) values 
            (@cToID, @cSKU, @cFromLOC, '', @cFromID, @nQty, 0, @cCartonID, '', CAST( @nFunc AS NVARCHAR( 4)), @cUserName)

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 98371  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Log fail  
               GOTO RollBackTran  
            END  

            SET @nQTY_Move = @nQTY_Move - @nPUOM_Div
            
            IF @nQTY_Move <= 0
               BREAK
         END
         GOTO Quit
      END  -- @cType = 'I'
         /*
         -- Get SSCC if the pallet still not ship yet
         -- Pallet will lose id when scan to container
         SET @cSSCC = ''
         SET @cToID_MbolKey = ''
         SELECT TOP 1 @cSSCC = PalletKey, 
                      @cToID_MbolKey = UserDefine03
         FROM dbo.PalletDetail PLTD WITH (NOLOCK)
         WHERE PLTD.Storerkey = @cStorerkey
         AND   PLTD.UserDefine01 = @cToID
         AND   PLTD.Status < '9'
         AND   NOT EXISTS ( SELECT 1 FROM dbo.MBOL MBOL WITH (NOLOCK)
                            WHERE PLTD.UserDefine03 = MBOL.MbolKey
                            AND   MBOL.Status = '9')
         --AND   EXISTS (
         --      SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
         --      WHERE PLTD.Storerkey = PD.Storerkey
         --      AND   PLTD.UserDefine01 = PD.ID
         --      AND   PD.Status < '9')

         IF ISNULL( @cSSCC, '') <> ''
         BEGIN
            -- If reuse pallet and the prev mbol already shipped
            -- need generate a new palletkey
            IF EXISTS ( SELECT 1 FROM Mbol WITH (NOLOCK) 
                        WHERE MbolKey = @cToID_MbolKey
                        AND   [Status] = '9')
               SET @cSSCC = ''
         END

         -- Gen SSCC if it is blank
         IF ISNULL( @cSSCC, '') = ''
         BEGIN
            SELECT @cItemClass = ItemClass
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   SKU = @cSKU

            IF ISNULL( @cItemClass, '') <> '001'
            BEGIN
               EXECUTE nspg_getkey
                  @KeyName       = 'MHAPSSCCP' ,
                  @fieldlength   = 17,    
                  @keystring     = @cCounter    Output,
                  @b_success     = @bSuccess    Output,
                  @n_err         = @nErrNo      Output,
                  @c_errmsg      = @cErrMsg     Output,
                  @b_resultset   = 0,
                  @n_batch       = 1

               IF @nErrNo <> 0 OR @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 98377
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get sscc fail
                  GOTO RollBackTran
               END

               SET @cSSCC = 'P' + @cCounter
            END
            ELSE
            BEGIN
               EXEC [rdt].[rdt_GenUCCLabelNo_02] 
                  @nMobile       = @nMobile,
                  @nFunc         = @nFunc,
                  @cLangCode     = @cLangCode,
                  @nStep         = @nStep,
                  @nInputKey     = 1,
                  @cStorerkey    = @cStorerkey,
                  @cOrderKey     = '',
                  @cPickSlipNo   = '',
                  @cTrackNo      = '',
                  @cSKU          = '',
                  @nCartonNo     = '',
                  @cLabelNo      = @cSSCC    OUTPUT,
                  @nErrNo        = @nErrNo   OUTPUT,
                  @cErrMsg       = @cErrMsg  OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran  
            END
         END

         IF ISNULL( @cSSCC, '') = ''
         BEGIN  
            SET @nErrNo = 98355  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen SSCC# fail  
            GOTO RollBackTran  
         END  

         IF ISNULL( @cToID, '') = ''
         BEGIN
            SET @nErrNo = 98382
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv shipper plt
            GOTO RollBackTran
         END

         WHILE @nQTY_Move > 0
         BEGIN
            SET @nCase_Qty = 0
            SET @nPD_Qty = 0

            -- Get pickdetailkey
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickDetailKey, Qty
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND   SKU = @cSKU
            AND   ID = @cToID
            ORDER BY PickDetailKey
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @nCase_Qty = ISNULL( SUM( Qty), 0)
               FROM dbo.PalletDetail WITH (NOLOCK) 
               WHERE PalletKey = @cSSCC
               AND   UserDefine01 = @cToID
               AND   SKU = @cSKU
               AND   Userdefine02 = @cPickDetailKey

               IF @nPD_Qty > @nCase_Qty
                  BREAK

               FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP

            SELECT @cOrderKey = O.OrderKey,
                   @cMBOLKey = O.MBOLKey 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
            WHERE PickDetailKey = @cPickDetailKey

            SELECT 
               @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
            FROM dbo.SKU S WITH (NOLOCK) 
            JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

            IF @nQTY_Move < @nPUOM_Div
               SET @nQty = @nQTY_Move
            ELSE
               SET @nQty = @nPUOM_Div
               
            -- Insert into pallet table. SSCC = palletkey 
            IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                              WHERE PalletKey = @cSSCC
                              AND   StorerKey = @cStorerKey)
            BEGIN
               -- Insert Pallet info
               INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cSSCC, @cStorerKey)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98356
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
                  GOTO RollBackTran
               END
            END

            -- Insert into palletdetail table. Need a loop here to insert every case scanned
            -- Insert with blank udf02-04 (pickdetailkey, mbolkey, orderkey) as we don't know the value yet
            -- Case id here is not unique
            IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                              WHERE PalletKey = @cSSCC
                              AND   UserDefine01 = @cToID
                              AND   CaseID = @cCartonID
                              AND   UserDefine04 = @cPickDetailKey
                              AND   [Status] < '9')
            BEGIN
               SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PalletDetail WITH (NOLOCK)
               WHERE PalletKey = @cSSCC
               AND   [Status] < '9'

               INSERT INTO dbo.PalletDetail 
               (PalletKey, PalletLineNumber, CaseID, StorerKey, Sku, Qty, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05) 
               VALUES
               (@cSSCC, @cPalletLineNumber, @cCartonID, @cStorerKey, @cSKU, @nQty, @cToID, @cPickDetailKey, @cMBOLKey, @cOrderKey, @cFromID)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98357
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PalletDetail WITH (ROWLOCK)
                  SET Qty = Qty + @nPUOM_Div
               WHERE PalletKey = @cSSCC
               AND   UserDefine01 = @cToID
               AND   CaseID = @cCartonID
               AND   UserDefine04 = @cPickDetailKey
               AND   [Status] < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98358
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltd err
                  GOTO RollBackTran
               END
            END   -- If not exists palletdetail

            SET @nQTY_Move = @nQTY_Move - @nPUOM_Div

            IF @nQTY_Move <= 0
               GOTO Quit
         END   -- @nQTY_Move > 0
         */
   END

   IF @nStep = 5
   BEGIN
      -- Insert record into the log table
      IF @cType = 'E'
      BEGIN
         -- Get SSCC if the pallet still not ship yet
         -- Pallet will lose id when scan to container
         SET @cSSCC = ''
         SET @cToID_MbolKey = ''
         SELECT TOP 1 @cSSCC = PalletKey,
                      @cToID_MbolKey = UserDefine03
         FROM dbo.PalletDetail PLTD WITH (NOLOCK)
         WHERE PLTD.Storerkey = @cStorerkey
         AND   PLTD.UserDefine01 = @cToID
         AND   PLTD.Status < '9'
         --AND   EXISTS (
         --      SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
         --      WHERE PLTD.Storerkey = PD.Storerkey
         --      AND   PLTD.UserDefine01 = PD.ID
         --      AND   PD.Status < '9')
         AND   NOT EXISTS ( SELECT 1 FROM dbo.MBOL MBOL WITH (NOLOCK)
                            WHERE PLTD.UserDefine03 = MBOL.MbolKey
                            AND   MBOL.Status = '9')

         IF ISNULL( @cSSCC, '') <> ''
         BEGIN
            -- If reuse pallet and the prev mbol already shipped
            -- need generate a new palletkey
            IF EXISTS ( SELECT 1 FROM Mbol WITH (NOLOCK) 
                        WHERE MbolKey = @cToID_MbolKey
                        AND   [Status] = '9')
               SET @cSSCC = ''
         END

         -- Gen SSCC if it is blank
         IF ISNULL( @cSSCC, '') = ''
         BEGIN
            SELECT @cItemClass = ItemClass
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   SKU = @cSKU

            IF ISNULL( @cItemClass, '') <> '001'
            BEGIN
               EXECUTE nspg_getkey
                  @KeyName       = 'MHAPSSCCP' ,
                  @fieldlength   = 17,    
                  @keystring     = @cCounter    Output,
                  @b_success     = @bSuccess    Output,
                  @n_err         = @nErrNo      Output,
                  @c_errmsg      = @cErrMsg     Output,
                  @b_resultset   = 0,
                  @n_batch       = 1

               IF @nErrNo <> 0 OR @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 98378
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get sscc fail
                  GOTO RollBackTran
               END

               SET @cSSCC = 'P' + @cCounter
            END
            ELSE
            BEGIN
               EXEC [rdt].[rdt_GenUCCLabelNo_02] 
                  @nMobile       = @nMobile,
                  @nFunc         = @nFunc,
                  @cLangCode     = @cLangCode,
                  @nStep         = @nStep,
                  @nInputKey     = 1,
                  @cStorerkey    = @cStorerkey,
                  @cOrderKey     = '',
                  @cPickSlipNo   = '',
                  @cTrackNo      = '',
                  @cSKU          = '',
                  @nCartonNo     = '',
                  @cLabelNo      = @cSSCC    OUTPUT,
                  @nErrNo        = @nErrNo   OUTPUT,
                  @cErrMsg       = @cErrMsg  OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran  
            END
         END

         IF ISNULL( @cSSCC, '') = ''
         BEGIN  
            SET @nErrNo = 98359  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen SSCC# fail  
            GOTO RollBackTran  
         END  

         -- Insert into pallet table. SSCC = palletkey 
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                           WHERE PalletKey = @cSSCC
                           AND   StorerKey = @cStorerKey)
         BEGIN
            -- Insert Pallet info
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cSSCC, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 98360
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
               GOTO RollBackTran
            END
         END

         IF ISNULL( @cToID, '') = ''
         BEGIN
            SET @nErrNo = 98383
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv shipper plt
            GOTO RollBackTran
         END

         -- Insert into palletdetail table. Need a loop here to insert every case scanned
         -- Insert with blank udf02-04 (pickdetailkey, orderkey, mbolkey) as we don't know the value yet
         -- Case id here is not unique
         --select '@cFromID', @cFromID, '@cToID', @cToID, '@cSKU', @cSKU, '@cUserName', @cUserName
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT CaseID, ISNULL( QtyMove, 0) 
         FROM rdt.rdtDPKLog WITH (NOLOCK) 
         WHERE FromID = @cFromID
         AND   DropID = @cToID
         AND   SKU = @cSKU
         AND   UserKey = @cUserName
         ORDER BY CaseID
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cCaseID, @nCaseID_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Get pickdetailkey
            DECLARE CUR_LOOP1 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickDetailKey, Qty
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND   SKU = @cSKU
            AND   ID = @cFromID
            ORDER BY PickDetailKey
            OPEN CUR_LOOP1
            FETCH NEXT FROM CUR_LOOP1 INTO @cPickDetailKey, @nPD_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @nCase_Qty = ISNULL( SUM( Qty), 0)
               FROM dbo.PalletDetail WITH (NOLOCK) 
               WHERE PalletKey = @cSSCC
               AND   UserDefine01 = @cToID
               AND   SKU = @cSKU
               AND   Userdefine02 = @cPickDetailKey

               IF @nPD_Qty > @nCase_Qty
                  BREAK

               FETCH NEXT FROM CUR_LOOP1 INTO @cPickDetailKey, @nPD_Qty
            END
            CLOSE CUR_LOOP1
            DEALLOCATE CUR_LOOP1

            SELECT @cOrderKey = O.OrderKey,
                     @cMBOLKey = O.MBOLKey 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
            WHERE PickDetailKey = @cPickDetailKey

            IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                              WHERE PalletKey = @cSSCC
                              AND   UserDefine01 = @cToID
                              AND   UserDefine02 = @cPickDetailKey
                              AND   CaseID = @cCaseID
                              AND   [Status] < '9')
            BEGIN
               SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PalletDetail WITH (NOLOCK)
               WHERE PalletKey = @cSSCC

               INSERT INTO dbo.PalletDetail 
               (PalletKey, PalletLineNumber, CaseID, StorerKey, Sku, Qty, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05) 
               VALUES
               (@cSSCC, @cPalletLineNumber, @cCaseID, @cStorerKey, @cSKU, @nCaseID_Qty, @cToID, @cPickDetailKey, @cMBOLKey, @cOrderKey, @cFromID)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 98361
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               --SET @cUserDefine02 = ''
               --SELECT @cUserDefine02 = UserDefine02 
               --FROM dbo.PalletDetail WITH (NOLOCK) 
               --WHERE PalletKey = @cSSCC
               --AND   UserDefine01 = @cToID
               --AND   CaseID = @cCaseID
               --AND   [Status] < '9'

               --IF @cUserDefine02 = @cPickDetailKey
               --BEGIN
                  UPDATE dbo.PalletDetail WITH (ROWLOCK)
                     SET Qty = Qty + @nCaseID_Qty
                  WHERE PalletKey = @cSSCC
                  AND   UserDefine01 = @cToID
                  AND   UserDefine02 = @cPickDetailKey
                  AND   CaseID = @cCaseID
                  AND   [Status] < '9'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 98362
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltd err
                     GOTO RollBackTran
                  END
               --END
               --ELSE
               --BEGIN
               --   SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               --   FROM dbo.PalletDetail WITH (NOLOCK)
               --   WHERE PalletKey = @cSSCC

               --   INSERT INTO dbo.PalletDetail 
               --   (PalletKey, PalletLineNumber, CaseID, StorerKey, Sku, Qty, UserDefine01, UserDefine02, UserDefine03, UserDefine04) 
               --   VALUES
               --   (@cSSCC, @cPalletLineNumber, @cCaseID, @cStorerKey, @cSKU, @nCaseID_Qty, @cToID, @cPickDetailKey, @cMBOLKey, @cOrderKey)

               --   IF @@ERROR <> 0
               --   BEGIN
               --      SET @nErrNo = 98374
               --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
               --      GOTO RollBackTran
               --   END
               --END

               --IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) 
               --            WHERE PalletKey <> @cSSCC
               --            AND   UserDefine01 = @cFromID
               --            AND   UserDefine02 = @cPickDetailKey
               --            AND   [Status] < '9')
               --BEGIN
               --   UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET 
               --      Qty = 0
               --   WHERE PalletKey <> @cSSCC
               --   AND   UserDefine01 = @cFromID
               --   AND   UserDefine02 = @cPickDetailKey
               --   AND   [Status] < '9'

               --   IF @@ERROR <> 0
               --   BEGIN
               --      SET @nErrNo = 98379
               --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
               --      GOTO RollBackTran
               --   END
               --END
            END

            FETCH NEXT FROM CUR_LOOP INTO @cCaseID, @nCaseID_Qty  
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP

         SELECT @cPackUOM3 = PACK.PACKUOM3
         FROM dbo.PACK PACK WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @cStorerKey
         AND   SKU.SKU = @cSKU

         SELECT @nQTY_Move = ISNULL( SUM( QtyMove), 0) 
         FROM rdt.rdtDPKLog WITH (NOLOCK) 
         WHERE FromID = @cFromID
         AND   DropID = @cToID
         AND   SKU = @cSKU
         AND   UserKey = @cUserName

         SET @nCaseID_Qty = @nQTY_Move

         SET @nMV_Alloc = 0
         SET @nMV_Pick = 0

         -- If move allocated qty, need to give a scope for rdt move
         -- Here is using a running no and stamp to dropid field to scope it 
         IF @nQTY_Alloc > 0 
         BEGIN
            SET @nMV_Alloc = @nQTY_Move

            SET @cMoveRefKey = ''
            SET @bSuccess = 1    
            EXECUTE   nspg_getkey    
               @KeyName    = 'MHAPRefKey',
               @fieldlength= 10,
               @keystring  = @cMoveRefKey OUTPUT,
               @b_Success  = @bSuccess    OUTPUT,
               @n_err      = @nErrNo      OUTPUT,
               @c_errmsg   = @cErrMsg     OUTPUT 

            IF NOT @bSuccess = 1    
            BEGIN    
               SET @nErrNo = 98363   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get RFKey Fail 
               GOTO RollBackTran
            END 

            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, PD.Qty
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.ID = @cFromID 
            AND   PD.Status < '9'
            AND   PD.SKU = @cSKU
            AND   LOC.Facility = @cFacility
            --AND   LOC.LocationCategory = 'STAGING'
            ORDER BY PickDetailKey
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               -- Exact match or PickDetail have less
               IF @nPD_Qty <= @nCaseID_Qty
               BEGIN
                  -- Confirm PickDetail
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     DropID = @cMoveRefKey,
                     TrafficCop = NULL
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 98364
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  SET @nCaseID_Qty = @nCaseID_Qty - @nPD_Qty -- Reduce balance 
                  SET @nCase_Qty = @nPD_Qty
               END
               -- PickDetail have more, need to split
               ELSE 
               BEGIN
                  -- Get new PickDetailkey
                  EXECUTE dbo.nspg_GetKey
                     @KeyName    = 'PICKDETAILKEY',
                     @fieldlength= 10,
                     @keystring  = @cNewPickDetailKey OUTPUT,
                     @b_Success  = @bSuccess    OUTPUT,
                     @n_err      = @nErrNo      OUTPUT,
                     @c_errmsg   = @cErrMsg     OUTPUT 

                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 98365
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
                     GOTO RollBackTran
                  END

                  -- Create a new PickDetail to hold the balance
                  INSERT INTO dbo.PICKDETAIL (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                     @nPD_Qty - @nCaseID_Qty, -- QTY
                     NULL, --TrafficCop,
                     '1'  --OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 98366
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                     GOTO RollBackTran
                  END

                  -- If pickdetail has more qty than case qty then split line needed. 
                  -- Update pickdetail.qty with no trafficcop
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nCaseID_Qty,
                     DropID = @cMoveRefKey,
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 98367
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                     GOTO RollBackTran
                  END

                  SET @nCase_Qty = @nCaseID_Qty
                  SET @nCaseID_Qty = 0 -- Reduce balance
               END

               SELECT @cOrderKey = O.OrderKey,
                      @cMBOLKey = O.MBOLKey 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
               WHERE PickDetailKey = @cPickDetailKey

               --if SUSER_NAME() = 'jameswong'
               --BEGIN
               --   select '@cPickDetailKey', @cPickDetailKey, '@cOrderKey', @cOrderKey, '@cMBOLKey', @cMBOLKey
               --END

               -- Stamp palletdetail with udf02-04 (pickdetailkey, orderkey, mbolkey) 
               -- for each case here. After stamp then update PAQty=QtyMove to indicate finish update
               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT CaseID, ISNULL( SUM( QtyMove), 0) 
               FROM rdt.rdtDPKLOG WITH (NOLOCK) 
               WHERE FromID = @cFromID
               AND   DropID = @cToID
               AND   PAQty = 0
               AND   UserKey = @cUserName
               GROUP BY CaseID
               OPEN CUR_UPD
               FETCH NEXT FROM CUR_UPD INTO @cCaseID, @nDPK_Qty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  UPDATE dbo.PalletDetail WITH (ROWLOCK) SET
                     UserDefine02 = @cPickDetailKey,
                     UserDefine03 = @cMBOLKey,
                     UserDefine04 = @cOrderKey
                  WHERE PalletKey = @cSSCC
                  AND   UserDefine01 = @cToID
                  AND   CaseID = @cCaseID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 98368
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltd err
                     GOTO RollBackTran
                  END

                  UPDATE RDT.RDTDPKLog WITH (ROWLOCK) SET 
                     PAQty = @nDPK_Qty,
                     BOMSKU = SUBSTRING( @cSSCC, 1, 20)
                  WHERE FromID = @cFromID
                  AND   DropID = @cToID
                  AND   PAQty = 0
                  AND   UserKey = @cUserName
                  AND   CaseID = CaseID

                  SET @nCase_Qty = @nCase_Qty - @nDPK_Qty

                  IF @nCase_Qty <= 0
                     BREAK

                  FETCH NEXT FROM CUR_UPD INTO @cCaseID, @nDPK_Qty
               END
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD

               IF @nCaseID_Qty <= 0
               BEGIN
                  SET @cOrderKey = ''
                  BREAK
               END

               FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey, @nPD_Qty
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP

            SET @nMV_Alloc = @nQTY_Move
         END

         -- If move picked qty then need to determine which order to move
         -- Only move full qty in order only.
         -- Assumption here 1 pallet only 1 order
         IF @nQTY_Pick > 0 
         BEGIN
            SET @nMV_Pick = @nQTY_Move     

            SET @cOrderKey = ''
            SET @cMoveRefKey = ''
            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   LOC = @cFromLOC
            AND   ID = @cFromID
            AND   SKU = @cSKU
            AND   [Status] < '9'

            SELECT TOP 1 @cPickDetailKey = PD.PickDetailKey,
                     @cOrderKey = O.OrderKey,
                     @cMBOLKey = O.MBOLKey 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
            WHERE O.OrderKey = @cOrderKey

            -- Stamp palletdetail with udf02-04 (pickdetailkey, orderkey, mbolkey) 
            -- for each case here. After stamp then update PAQty=QtyMove to indicate finish update
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT CaseID, ISNULL( SUM( QtyMove), 0) 
            FROM rdt.rdtDPKLOG WITH (NOLOCK) 
            WHERE FromID = @cFromID
            AND   DropID = @cToID
            AND   PAQty = 0
            AND   UserKey = @cUserName
            GROUP BY CaseID
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @cCaseID, @nDPK_Qty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE RDT.RDTDPKLog WITH (ROWLOCK) SET 
                  PAQty = @nDPK_Qty,
                  BOMSKU = SUBSTRING( @cSSCC, 1, 20)
               WHERE FromID = @cFromID
               AND   DropID = @cToID
               AND   PAQty = 0
               AND   UserKey = @cUserName
               AND   CaseID = CaseID

               SET @nCaseID_Qty = @nCaseID_Qty - @nDPK_Qty

               IF @nCaseID_Qty <= 0
                  BREAK

               FETCH NEXT FROM CUR_UPD INTO @cCaseID, @nDPK_Qty
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
         END

         -- EXEC move
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, 
            @cSourceType = 'rdtfnc_PalletConsolidate_SSCC',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cFromLOC,
            @cFromID     = @cFromID,     
            @cToID       = @cToID,       
            @cSKU        = @cSKU,
            @nQTY        = @nQTY_Move,
            @nQTYAlloc   = @nMV_Alloc,
            @nQTYPick    = @nMV_Pick, 
            @nFunc       = @nFunc, 
            @cOrderKey   = @cOrderKey,
            @cDropID     = @cMoveRefKey
                  
         IF @nErrNo <> 0
            GOTO RollBackTran
         ELSE
         BEGIN
            -- After finish move then need to clear the dropid
            -- we stamp before
            IF ISNULL( @cMoveRefKey, '') <> ''
            BEGIN
               DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT PickDetailKey
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE DropID = @cMoveRefKey
               OPEN CUR_LOOP
               FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
                      DropID = ''
                     ,EditWho    = SUSER_NAME()
                     ,EditDate   = GETDATE()
                     ,Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 98370   
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --REL PDTL FAIL 
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM CUR_LOOP INTO @cPickDetailKey
               END
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
            END

            -- Clear log record
            DELETE FROM rdt.rdtDPKLog 
            WHERE FromID = @cFromID
            AND   DropID = @cToID
            AND   UserKey = @cUserName

            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4', -- Move
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cID           = @cFromID,
               @cToID         = @cToID, 
               @cUOM          = @cPackUOM3,
               @nQTY          = @nQTY_Move,
               @cOrderKey     = @cOrderKey,
               @cRefNo1       = 'PALLET PARTIAL MOVE'
         END
      END
   END

   -- Insert From ID (ARS pallet) case detail into pallet detail
   IF @nStep = 6
   BEGIN
      -- Insert record into the log table
      IF @cType = 'I'
      BEGIN
         SELECT 
            @nPUOM_Div = CAST( Pack.CaseCNT AS INT) 
         FROM dbo.SKU S WITH (NOLOCK) 
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

         WHILE @nQTY_Move > 0
         BEGIN
            -- (james02)
            IF @nQTY_Move < @nPUOM_Div
               SET @nQty = @nQTY_Move
            ELSE
               SET @nQty = @nPUOM_Div
            
            INSERT INTO rdt.rdtDPKLog (DropID, SKU, FromLoc, FromLot, FromID, QtyMove, PAQty, CaseID, BOMSKU, TaskdetailKey, UserKey) values 
            (@cToID, @cSKU, @cFromLOC, '', @cFromID, @nQty, 0, @cCartonID, '', CAST( @nFunc AS NVARCHAR( 4)), @cUserName)

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 98371  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Log fail  
               GOTO RollBackTran  
            END  

            SET @nQTY_Move = @nQTY_Move - @nPUOM_Div
            
            IF @nQTY_Move <= 0
               BREAK
         END
         GOTO Quit
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_PltConsoSSCC_BuildPlt

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') in (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_UPD') in (0 , 1)
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_PltConsoSSCC_BuildPlt

END

GO