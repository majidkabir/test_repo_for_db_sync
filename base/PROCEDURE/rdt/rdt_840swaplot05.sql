SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************/      
/* Store procedure: rdt_840SwapLot05                                    */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: H&M swap lot (modified from rdt_840SwapLot03)               */      
/*          Swap between other load and available stock                 */      
/*                                                                      */      
/* Called from: rdtfnc_PackByTrackNo                                    */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date        Rev  Author      Purposes                                */      
/* 2022-03-08  1.0  yeekung     WMS-19134. Created                      */     
/* 2022-04-26  1.1  yeekung     WMS-19442. Change PackCarton(yeeKung01) */ 
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_840SwapLot05] (      
   @n_Mobile         INT,       
   @c_Storerkey      NVARCHAR( 15),       
   @c_OrderKey       NVARCHAR( 10),       
   @c_TrackNo        NVARCHAR( 20),       
   @c_PickSlipNo     NVARCHAR( 10),       
   @n_CartonNo       INT,       
   @c_LOC            NVARCHAR( 10),       
   @c_ID             NVARCHAR( 18),       
   @c_SKU            NVARCHAR( 20),       
   @c_Lottable01     NVARCHAR( 18),       
   @c_Lottable02     NVARCHAR( 18),       
   @c_Lottable03     NVARCHAR( 18),       
   @d_Lottable04     DATETIME,       
   @d_Lottable05     DATETIME,       
   @c_Barcode        NVARCHAR( 40),       
   @b_Success        INT = 1  OUTPUT,      
   @n_ErrNo          INT      OUTPUT,       
   @c_ErrMsg         NVARCHAR(250) OUTPUT      
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE       
           @n_ExpectedQty           INT,       
           @n_PackedQty             INT,       
           @c_LabelNo               NVARCHAR( 20),       
           @c_LoadKey               NVARCHAR( 10),       
           @c_Route                 NVARCHAR( 10),       
           @c_ConsigneeKey          NVARCHAR( 15),       
           @c_UserName              NVARCHAR( 18),       
           @c_CurLabelNo            NVARCHAR( 20),       
           @c_CurLabelLine          NVARCHAR( 5),           
           @c_TargetPickDetailKey   NVARCHAR( 10),       
           @c_TargetLot             NVARCHAR( 10),       
           @c_TargetID              NVARCHAR( 18),       
           @c_NewID                 NVARCHAR( 18),       
           @c_NewLOT                NVARCHAR( 10),       
           @c_Lot                   NVARCHAR( 10),       
           @n_err                   INT,       
           @c_LangCode              NVARCHAR( 3),       
           @c_PickDetailKey         NVARCHAR( 10),       
           @nTranCount              INT,       
           @nLLI_Qty                INT,       
           @nPD_Qty                 INT,       
           @n_Continue              INT,       
           @n_SwapLot               INT,       
           @n_Func                  INT,      
           @n_Step                  INT,      
           @n_InputKey              INT,      
           @c_SQLStatement          NVARCHAR(2000),      
           @c_SQLParms              NVARCHAR(2000),      
           @c_GenLabelNo_SP         NVARCHAR( 20),      
           @c_TargetOrderKey        NVARCHAR( 10),      
           @c_TargetLOC             NVARCHAR( 10),      
           @c_NewLoc                NVARCHAR( 10),      
           @c_Authority_ScanInLog   NVARCHAR( 1),      
           @nPack_QTY               INT,      
           @cCartonType             NVARCHAR( 10),      
           @n_IsMoveOrder           INT,    -- ZG01      
       @c_CaseID                NVARCHAR( 20)      
      
   SET @n_IsMoveOrder = 0     -- ZG01      
   SET @n_ErrNo = 0      
   SET @n_SwapLot = 1      
   SET @nPack_QTY = 1      
         
   SELECT @n_Func = Func,       
          @n_Step = Step,       
          @n_InputKey = InputKey,       
          @c_CaseID = V_CaseID      
   FROM RDT.RDTMOBREC WITH (NOLOCK)       
   WHERE Mobile = @n_Mobile      
      
   IF ISNULL( @c_OrderKey, '') = ''      
   BEGIN      
      SET @n_ErrNo = 184151           
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Order'          
      GOTO Quit_WithoutTran      
   END      
      
   IF ISNULL( @c_SKU, '') = ''       
   BEGIN      
      SET @n_ErrNo = 184152          
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid SKU'          
      GOTO Quit_WithoutTran      
   END      
      
   IF ISNULL( @c_Lottable02, '') = ''       
   BEGIN      
      SET @n_ErrNo = 184153          
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid LOT02'          
      GOTO Quit_WithoutTran      
   END      
      
   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)       
                   WHERE StorerKey = @c_Storerkey      
                   AND   OrderKey = @c_OrderKey      
                   AND   SKU = @c_SKU      
                   AND   [Status] < '9')      
   BEGIN      
      SET @n_ErrNo = 184154          
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU NOT IN ORD'          
      GOTO Quit_WithoutTran      
   END      
      
   SELECT @c_UserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @n_Mobile      
      
   -- If it is not Sales type order then no need swap lot. Check validity of 2D barcode      
   IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)       
                   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)      
                   WHERE C.ListName = 'HMCOSORD'       
                   AND   C.Short = 'S'      
                   AND   O.OrderKey = @c_Orderkey      
                   AND   O.StorerKey = @c_StorerKey)      
   BEGIN      
      SET @n_SwapLot = 0      
            
      -- SKU + Lottable02 must match pickdetail for this orders      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)       
                      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT      
                      WHERE PD.StorerKey = @c_Storerkey      
                      AND   PD.OrderKey = @c_OrderKey      
                      AND   PD.SKU = @c_SKU      
                      AND   PD.Status < '9'      
                      AND   PD.QtyMoved < PD.QTY      
                      AND   LA.Lottable02 = @c_Lottable02)      
      BEGIN      
         SET @n_ErrNo = 184155          
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Label'          
         GOTO Quit_WithoutTran      
      END      
            
      -- Get carton info      
      DECLARE @c_UPC NVARCHAR(30)      
      SET @c_UPC = ''      
      SELECT TOP 1 @c_UPC = UPC FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo      
            
      -- Get lottable12 of the carton      
      IF @c_UPC <> ''      
      BEGIN      
         DECLARE @c_Carton_L12 NVARCHAR( 30)      
         DECLARE @c_Scan_L12 NVARCHAR( 30)      
               
         SET @c_Carton_L12 = SUBSTRING( @c_UPC, 22, 6)       
         SET @c_Scan_L12 = substring( @c_Lottable02, 7, 6)       
                  
         -- Check different lottable12 (HMOrderNumber)      
         IF @c_Carton_L12 <> @c_Scan_L12      
         BEGIN      
            SET @n_ErrNo = 184156          
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Diff HMOrder'          
            GOTO Quit_WithoutTran      
         END      
      END      
   END      
            
   SET @n_ExpectedQty = 0          
   SELECT @n_ExpectedQty = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail WITH (NOLOCK)          
   WHERE Orderkey = @c_Orderkey          
   AND   Storerkey = @c_StorerKey          
   AND   [Status] < '9'          
   AND   SKU = @c_SKU      
          
   SET @n_PackedQty = 0          
   SELECT @n_PackedQty = ISNULL(SUM(Qty), 0) FROM RDT.rdtTrackLog WITH (NOLOCK)          
   WHERE Orderkey = @c_Orderkey          
   AND   Storerkey = @c_StorerKey          
   AND   [Status] < '9'      
   AND   SKU = @c_SKU      
      
   IF (@n_PackedQty + 1) > @n_ExpectedQty       
   BEGIN      
      SET @n_ErrNo = 184157      
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU OVERPACKED'      
      GOTO Quit_WithoutTran      
   END      
      
   SET @nTranCount = @@TRANCOUNT        
   BEGIN TRAN  -- Begin our own transaction        
   SAVE TRAN rdt_840SwapLot05 -- For rollback or commit only our own transaction        
      
   DECLARE @cur CURSOR      
   SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR       
   SELECT PickDetailKey      
   FROM dbo.PICKDETAIL WITH (NOLOCK)      
   WHERE Orderkey = @c_Orderkey          
   AND   Storerkey = @c_StorerKey          
   AND   [Status] < '9'          
   AND   SKU = @c_SKU      
   AND   QtyMoved > 0      
   OPEN @cur      
   FETCH NEXT FROM @cur INTO @c_PickDetailKey      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      UPDATE dbo.PickDetail SET      
         QtyMoved = 0,      
         EditDate = GETDATE(),      
         EditWho = SUSER_SNAME()      
      WHERE PickDetailKey = @c_PickDetailKey      
      
      IF @@ERROR <> 0        
      BEGIN        
         SET @n_ErrNo = 184158        
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --QtyMoved Fail        
         EXEC rdt.rdtSetFocusField @n_Mobile, 6      
         GOTO RollBackTran        
      END      
      
      FETCH NEXT FROM @cur INTO @c_PickDetailKey      
   END      
         
   IF @n_SwapLot = 1      
   BEGIN      
      SELECT @c_LoadKey = LoadKey      
      FROM dbo.Orders WITH (NOLOCK)      
      WHERE OrderKey = @c_OrderKey      
      
      SET @c_TargetOrderKey = ''      
      SET @c_PickDetailKey = ''      
      
      -- 1.1 Exact match      
      SELECT TOP 1 @c_TargetOrderKey = PD.OrderKey      
      FROM dbo.PickDetail PD WITH (NOLOCK)         
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
      WHERE PD.StorerKey = @c_Storerkey        
      AND   PD.SKU = @c_SKU        
      AND   PD.Status < '9'        
      AND   PD.QtyMoved < PD.QTY        
      AND   LA.Lottable02 = @c_Lottable02      
      AND   O.OrderKey = @c_OrderKey        
      
      -- 2. Swap with other loadkey      
      IF ISNULL( @c_TargetOrderKey, '') = ''      
      BEGIN      
         SELECT TOP 1       
            @c_TargetOrderKey = PD.OrderKey,      
            @c_TargetLOC =  PD.LOC,      
            @c_TargetID = PD.ID,      
            @c_TargetLot = PD.LOT,      
            @c_TargetPickDetailKey = PD.PickDetailkey      
         FROM dbo.PickDetail PD WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
         WHERE PD.StorerKey = @c_Storerkey        
         AND   PD.SKU = @c_SKU        
         AND   PD.Status < '9'        
         AND   PD.Qty = 1      
         AND   PD.QtyMoved < PD.QTY        
         AND   LA.Lottable02 = @c_Lottable02      
         AND   O.LoadKey <> @c_LoadKey       
         AND   PD.LOC IN (      
               SELECT DISTINCT PD.LOC      
               FROM dbo.PickDetail PD WITH (NOLOCK)         
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
               WHERE PD.StorerKey = @c_Storerkey        
               AND   PD.SKU = @c_SKU        
             AND   PD.Status < '9'        
               AND   PD.QtyMoved < PD.QTY        
               AND   O.LoadKey = @c_LoadKey)      
      
         IF ISNULL(  @c_TargetOrderKey, '') <> ''       
         BEGIN      
            SELECT TOP 1       
               @c_Lot = PD.LOT,      
               @c_PickDetailKey = PD.PickDetailkey      
            FROM dbo.PickDetail PD WITH (NOLOCK)         
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
            WHERE PD.StorerKey = @c_Storerkey        
            AND   PD.SKU = @c_SKU        
            AND   PD.Status < '9'        
            AND   PD.Qty = 1      
            AND   PD.QtyMoved < PD.QTY        
            AND   PD.LOC = @c_TargetLOC      
            AND   PD.ID = @c_TargetID      
            AND O.OrderKey = @c_OrderKey        
      
            IF @c_Lot <> ''      
            BEGIN      
               -- Swap original lot         
               UPDATE PickDetail WITH (ROWLOCK) SET         
                  EditDate = GETDATE(),            
                  EditWho = 'rdt.' + sUser_sName(),            
                  Lot = @c_TargetLot,         
                  QtyMoved = 1,         
                  Trafficcop = NULL        
               WHERE PickDetailKey = @c_PickDetailKey        
           
               IF @@ERROR <> 0        
               BEGIN        
                  SET @n_ErrNo = 184158        
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Swap Lot Fail        
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6      
                  GOTO RollBackTran        
               END      
                                
               -- Swap target lot        
               UPDATE PickDetail WITH (ROWLOCK) SET         
                  EditDate = GETDATE(),            
                  EditWho = 'rdt.' + sUser_sName(),            
                  Lot = @c_Lot,         
                  Trafficcop = NULL        
               WHERE PickDetailKey = @c_TargetPickDetailKey        
           
               IF @@ERROR <> 0        
                  BEGIN        
                  SET @n_ErrNo = 184159        
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Swap Lot Fail        
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6      
                  GOTO RollBackTran        
               END       
            END      
         END      
      END      
      ELSE      
      BEGIN      
         UPDATE TOP (1) dbo.PickDetail SET       
            QTYMoved = QTYMoved + 1      
         FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PD.StorerKey = @c_Storerkey      
            AND PD.OrderKey = @c_OrderKey      
            AND PD.SKU = @c_SKU      
            AND PD.Status < '9'      
            AND PD.QtyMoved < PD.QTY      
            AND LA.Lottable02 = @c_Lottable02      
      
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_ErrNo = 184177          
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') ----'UPDPKDET Fail'       
            EXEC rdt.rdtSetFocusField @n_Mobile, 6      
            GOTO RollBackTran          
         END       
      END      
      
      -- 3. Swap with available inventory         
      IF ISNULL( @c_TargetOrderKey, '') = ''      
      BEGIN      
         SELECT TOP 1 @c_NewLOT  = LLI.LOT, @c_NewID = ID, @c_NewLoc = LLI.LOC      
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)        
         WHERE LLI.StorerKey = @c_Storerkey        
         AND   LLI.SKU = @c_SKU        
         AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0        
         AND   LA.Lottable02 = @c_Lottable02         
         AND LOC IN (      
            SELECT DISTINCT PD.LOC      
            FROM dbo.PickDetail PD WITH (NOLOCK)         
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
            WHERE PD.StorerKey = @c_Storerkey        
            AND   PD.SKU = @c_SKU        
            AND   PD.Status < '9'        
            AND   PD.QtyMoved < PD.QTY        
            AND   O.LoadKey = @c_LoadKey  )      
      
         SELECT TOP 1       
            @c_TargetOrderKey = PD.OrderKey,  -- only get the orderkey here to show swap successful      
            @c_Lot = PD.LOT,      
            @c_PickDetailKey = PD.PickDetailkey      
         FROM dbo.PickDetail PD WITH (NOLOCK)         
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT        
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey      
         WHERE PD.StorerKey = @c_Storerkey        
         AND   PD.SKU = @c_SKU        
         AND   PD.Status < '9'        
         AND   PD.Qty = 1      
         AND   PD.QtyMoved < PD.QTY        
         AND   PD.LOC = @c_NewLoc      
         AND   PD.ID = @c_NewID      
         AND   O.LoadKey = @c_LoadKey        
      
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET         
            EditDate = GETDATE(),            
            EditWho = 'rdt.' + sUser_sName(),            
            Lot = @c_NewLOT,         
            ID = @c_NewID,         
            QtyMoved = 1         
         WHERE PickDetailKey = @c_PickDetailKey        
      
         IF @@ERROR <> 0        
            BEGIN        
            SET @n_ErrNo = 184160        
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Swap Lot Fail        
            EXEC rdt.rdtSetFocusField @n_Mobile, 6      
            GOTO RollBackTran        
         END       
      END      
      
      IF ISNULL( @c_TargetOrderKey, '') = ''      
      BEGIN        
         SET @n_ErrNo = 184161        
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Swap Lot Fail        
         EXEC rdt.rdtSetFocusField @n_Mobile, 6      
         GOTO RollBackTran        
      END       
   END   -- End of @n_Swap = 1      
         
   -- Insert pack here      
   IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)          
              WHERE PickSlipNo = @c_PickSlipNo          
              AND Storerkey = @c_Storerkey           
              AND CartonNo = @n_CartonNo          
              AND UserName = @c_UserName          
              AND SKU = @c_SKU)   -- can scan many sku into 1 carton          
   BEGIN          
      UPDATE rdt.rdtTrackLog WITH (ROWLOCK) SET           
         Qty = ISNULL(Qty, 0) + 1,          
         EditWho = @c_UserName,          
         EditDate = GetDate()          
      WHERE PickSlipNo = @c_PickSlipNo          
      AND Storerkey = @c_Storerkey           
      AND CartonNo = @n_CartonNo          
      AND UserName = @c_UserName          
      AND SKU = @c_SKU          
       
      IF @@ERROR <> 0          
      BEGIN          
         SET @n_ErrNo = 184162          
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UpdLog Failed'          
         EXEC rdt.rdtSetFocusField @n_Mobile, 6          
         GOTO RollBackTran          
      END          
   END          
   ELSE          
   BEGIN          
      INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )          
      VALUES (@c_PickSlipNo, @n_Mobile, @c_UserName, @c_Storerkey, @c_Orderkey, @c_TrackNo, @c_SKU, 1, @n_CartonNo  )          
       
       IF @@ERROR <> 0          
       BEGIN          
         SET @n_ErrNo = 184163          
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsLog Failed'          
         EXEC rdt.rdtSetFocusField @n_Mobile, 6          
         GOTO RollBackTran          
      END          
   END          
      
   -- Create PackHeader if not yet created          
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)          
   BEGIN          
      SELECT @c_LoadKey = ISNULL(RTRIM(LoadKey),'')          
           , @c_Route = ISNULL(RTRIM(Route),'')          
           , @c_ConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')          
      FROM dbo.Orders WITH (NOLOCK)          
      WHERE Orderkey = @c_Orderkey          
      
      -- 1st carton type insert from interface      
      SELECT @cCartonType = CartonType      
      FROM dbo.PackInfo WITH (NOLOCK)      
      WHERE PickSlipNo = @c_PickSlipNo      
      AND   CartonNo = 1      
            
      INSERT INTO dbo.PACKHEADER          
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS], ConsoOrderKey)           
      VALUES          
      (@c_PickSlipNo, @c_Storerkey, @c_Orderkey, @c_LoadKey, @c_Route, @c_ConsigneeKey, '', 0, '0', ISNULL( @cCartonType, ''))           
                
       IF @@ERROR <> 0          
       BEGIN          
         SET @n_ErrNo = 184164          
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsPKHDR Failed'          
         EXEC rdt.rdtSetFocusField @n_Mobile, 6          
         GOTO RollBackTran          
      END          
   END          
      
   -- Update PackDetail.Qty if it is already exists          
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)          
              WHERE StorerKey = @c_Storerkey          
              AND PickSlipNo = @c_PickSlipNo          
              AND CartonNo = @n_CartonNo          
              AND SKU = @c_SKU      
              AND UPC = @c_Barcode) -- different 2D barcode split to different packdetail line      
   BEGIN          
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET           
         Qty = Qty + @nPack_QTY,          
         EditDate = GETDATE(),          
         EditWho = 'rdt.' + sUser_sName()          
      WHERE StorerKey = @c_Storerkey          
      AND PickSlipNo = @c_PickSlipNo          
      AND CartonNo = @n_CartonNo          
      AND SKU = @c_SKU          
      AND UPC = @c_Barcode      
                
      IF @@ERROR <> 0          
      BEGIN          
         SET @n_ErrNo = 184165          
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UPDPKDET Failed'          
         EXEC rdt.rdtSetFocusField @n_Mobile, 6          
         GOTO RollBackTran          
      END          
   END          
   ELSE     -- Insert new PackDetail          
   BEGIN          
      -- Check if same carton exists before. Diff sku can scan into same carton          
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)          
                 WHERE StorerKey = @c_Storerkey          
                 AND PickSlipNo = @c_PickSlipNo          
                 AND CartonNo = @n_CartonNo)          
      BEGIN          
         IF @n_CartonNo = 1 AND @n_SwapLot = 1      
         BEGIN      
         --   SELECT TOP 1 @c_LabelNo = CaseID      
         --   FROM dbo.PICKDETAIL WITH (NOLOCK)      
         --   WHERE Storerkey = @c_Storerkey      
         --   AND   OrderKey = @c_OrderKey      
         --   AND   Sku = @c_SKU      
         --   ORDER BY 1      
         --END      
         --ELSE      
         --BEGIN      
            SET @c_GenLabelNo_SP = rdt.RDTGetConfig( @n_Func, 'PackByTrackNoGenLabelNo_SP', @c_Storerkey)       
            IF @c_GenLabelNo_SP NOT IN ('', '0') AND       
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_GenLabelNo_SP AND type = 'P')      
            BEGIN      
               SET @n_ErrNo = 0      
               SET @c_SQLStatement = 'EXEC rdt.' + RTRIM( @c_GenLabelNo_SP) +           
                  ' @nMobile, @nFunc, @c_LangCode, @nStep, @nInputKey, @c_Storerkey, @c_OrderKey, @cPickSlipNo, ' +       
                  ' @cTrackNo, @c_SKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT '          
               SET @c_SQLParms =      
                  '@nMobile                   INT,           ' +      
                  '@nFunc                     INT,           ' +      
                  '@c_LangCode                 NVARCHAR( 3),  ' +      
                  '@nStep                     INT,           ' +      
                  '@nInputKey                 INT,           ' +      
                  '@c_Storerkey                NVARCHAR( 15), ' +      
                  '@c_OrderKey                 NVARCHAR( 10), ' +      
                  '@cPickSlipNo               NVARCHAR( 10), ' +      
                  '@cTrackNo                  NVARCHAR( 20), ' +      
                  '@c_SKU                      NVARCHAR( 20), ' +      
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +      
                  '@nCartonNo                 INT           OUTPUT, ' +      
                  '@n_ErrNo                    INT           OUTPUT, ' +      
                  '@c_ErrMsg                   NVARCHAR( 20) OUTPUT  '       
                     
               EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms,           
       @n_Mobile, @n_Func, @c_LangCode, @n_Step, @n_InputKey, @c_Storerkey, @c_OrderKey, @c_PickSlipNo,       
                  @c_TrackNo, @c_SKU, @c_LabelNo OUTPUT, @n_CartonNo OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT       
      
               IF @n_ErrNo <> 0      
               BEGIN          
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')      
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6          
                  GOTO RollBackTran          
               END          
            END      
            ELSE      
            BEGIN      
               -- Get new LabelNo          
               EXECUTE isp_GenUCCLabelNo          
                        @c_Storerkey,          
                        @c_LabelNo    OUTPUT,          
                        @b_Success     OUTPUT,          
                        @n_ErrNo       OUTPUT,          
                        @c_ErrMsg      OUTPUT          
       
               IF @b_Success <> 1          
               BEGIN          
                  SET @n_ErrNo = 184166          
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'          
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6          
                  GOTO RollBackTran          
               END          
            END      
         END      
      
         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign          
         INSERT INTO dbo.PackDetail          
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC, LOTTABLEVALUE)          
         VALUES          
            (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_Storerkey, @c_SKU, @nPack_QTY,          
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @c_CaseID, @c_Barcode, @c_Barcode)         
      
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_ErrNo = 184166          
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'          
            EXEC rdt.rdtSetFocusField @n_Mobile, 6          
            GOTO RollBackTran          
         END          
      END          
      ELSE          
      BEGIN          
         SET @c_CurLabelNo = ''          
         SET @c_CurLabelLine = ''          
                   
         SELECT TOP 1 @c_CurLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)           
         WHERE StorerKey = @c_Storerkey          
         AND PickSlipNo = @c_PickSlipNo          
         AND CartonNo = @n_CartonNo          
       
         SELECT @c_CurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)            
         FROM PACKDETAIL WITH (NOLOCK)            
         WHERE StorerKey = @c_Storerkey          
   AND PickSlipNo = @c_PickSlipNo          
         AND CartonNo = @n_CartonNo          
       
         -- need to use the existing labelno          
         INSERT INTO dbo.PackDetail          
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC, LOTTABLEVALUE)          
         VALUES          
            (@c_PickSlipNo, @n_CartonNo, @c_CurLabelNo, @c_CurLabelLine, @c_Storerkey, @c_SKU, @nPack_QTY,          
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @c_CaseID, @c_Barcode, @c_Barcode)          
      
         IF @@ERROR <> 0          
         BEGIN          
            SET @n_ErrNo = 184168          
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'          
            EXEC rdt.rdtSetFocusField @n_Mobile, 6          
            GOTO RollBackTran          
         END         
               
         SET @c_LabelNo = @c_CurLabelNo       
      END          
   END          
         
   IF @n_SwapLot = 0        
   BEGIN      
      DECLARE @c_PDBorrow_Key  NVARCHAR(10)      
      DECLARE @c_PDBorrow_Line NVARCHAR(5)      
      DECLARE @c_PDBorrow_LOT  NVARCHAR(10)      
      DECLARE @c_PDBorrow_LOC  NVARCHAR(10)      
      DECLARE @c_PDBorrow_ID   NVARCHAR(18)      
      DECLARE @n_PDBorrow_QTY  INT      
      DECLARE @c_PDOwn_Key     NVARCHAR(10)      
      DECLARE @c_PDOwn_LOT     NVARCHAR(10)      
      DECLARE @n_PDOwn_QTY     INT      
      DECLARE @n_PDOwn_MoveQTY INT      
      
      SET @c_PDOwn_Key = ''      
      SET @c_PDBorrow_Key = ''      
      
      -- Get carton info      
      SELECT TOP 1       
         @c_LabelNo = LabelNo       
      FROM dbo.PackDetail WITH (NOLOCK)          
      WHERE StorerKey = @c_Storerkey          
         AND PickSlipNo = @c_PickSlipNo          
         AND CartonNo = @n_CartonNo          
         AND SKU = @c_SKU      
         AND UPC = @c_Barcode      
      
      -- Find own/open PickDetail to offset      
      SET @c_PDOwn_Key = ''      
      SELECT TOP 1       
         @c_PDOwn_Key = PickDetailKey      
      FROM dbo.PickDetail PD WITH (NOLOCK)       
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)      
      WHERE PD.StorerKey = @c_Storerkey      
         AND PD.OrderKey = @c_OrderKey      
         AND PD.SKU = @c_SKU      
         AND PD.QTY > 0      
         AND PD.Status < '9'      
         AND (PD.DropID = @c_LabelNo OR PD.DropID = '') -- own carton or no carton      
         AND PD.QTY > PD.QTYMoved   -- with balance      
         AND LA.Lottable02 = @c_Lottable02      
            
      -- Found own/open PickDetail      
      IF @c_PDOwn_Key <> ''      
      BEGIN      
         -- Reduce other PickDetail      
     UPDATE PickDetail SET      
      QTYMoved = QTYMoved + 1,       
      --DropID = CASE WHEN DropID = '' THEN @c_LabelNo ELSE DropID END,    -- ZG01      
      EditWho = SUSER_SNAME(),       
      EditDate = GETDATE(),       
      TrafficCop = NULL      
     WHERE PickDetailKey = @c_PDOwn_Key      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_ErrNo = 184169      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail      
            GOTO RollBackTran      
         END      
         GOTO Stamp_CaseID    -- ZG01      
    END      
               
      -- Find other PickDetail to borrow      
      SET @c_PDBorrow_Key = ''      
      SELECT TOP 1       
         @c_PDBorrow_Key = PickDetailKey,       
         @c_PDBorrow_Line = OrderLineNumber,       
         @c_PDBorrow_LOT = PD.LOT,       
         @c_PDBorrow_LOC = PD.LOC,       
         @c_PDBorrow_ID = PD.ID,       
         @n_PDBorrow_QTY = QTY      
      FROM dbo.PickDetail PD WITH (NOLOCK)       
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)      
      WHERE PD.StorerKey = @c_Storerkey      
         AND PD.OrderKey = @c_OrderKey      
         AND PD.SKU = @c_SKU      
         AND PD.QTY > 0      
         AND PD.Status < '9'      
         AND PD.DropID <> @c_LabelNo -- other carton      
         AND PD.QTY > PD.QTYMoved    -- with balance      
         AND LA.Lottable02 = @c_Lottable02      
      
      -- Found other PickDetail to borrow      
      IF @c_PDBorrow_Key <> ''      
      BEGIN      
         -- Find own PickDetail to topup (avoid split line, 1 QTY 1 line), but must be same line, LOT, LOC, ID      
         SET @c_PDOwn_Key = ''      
         SELECT TOP 1       
            @c_PDOwn_Key = PickDetailKey      
         FROM dbo.PickDetail PD WITH (NOLOCK)       
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PD.StorerKey = @c_Storerkey      
            AND PD.OrderKey = @c_OrderKey      
            AND PD.SKU = @c_SKU      
            AND PD.QTY > 0      
            AND PD.Status < '9'      
            AND PD.DropID = @c_LabelNo -- own carton or no carton      
            AND PD.OrderLineNumber = @c_PDBorrow_Line      
            AND PD.LOT = @c_PDBorrow_LOT      
            AND PD.LOC = @c_PDBorrow_LOC      
            AND PD.ID = @c_PDBorrow_ID      
               
         -- Top up      
         IF @c_PDOwn_Key <> ''      
         BEGIN      
            -- Reduce other      
            UPDATE PickDetail SET      
               QTY = QTY - 1,       
               EditDate = GETDATE(),      
               EditWho  = SUSER_SNAME(),      
               Trafficcop = NULL      
            WHERE PickDetailKey = @c_PDBorrow_Key      
            IF @@ERROR <> 0      
            BEGIN      
               SET @n_ErrNo = 184170      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
                              
            -- Increase own      
            UPDATE PickDetail SET      
               QTY = QTY + 1,       
               QTYMoved = QTYMoved + 1,       
               EditDate = GETDATE(),      
               EditWho  = SUSER_SNAME(),      
               Trafficcop = NULL      
            WHERE PickDetailKey = @c_PDOwn_Key      
            IF @@ERROR <> 0      
            BEGIN      
               SET @n_ErrNo = 184171      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
         END      
               
         -- Split line      
         ELSE       
         BEGIN               
            -- Get new PickDetailkey      
            DECLARE @cNewPickDetailKey NVARCHAR( 10)      
            EXECUTE dbo.nspg_GetKey      
               'PICKDETAILKEY',      
               10 ,      
               @cNewPickDetailKey OUTPUT,      
 @b_Success         OUTPUT,      
               @n_ErrNo           OUTPUT,      
               @c_ErrMsg          OUTPUT      
            IF @b_Success <> 1      
            BEGIN      
               SET @n_ErrNo = 87078      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- GetKey Fail      
               GOTO RollBackTran      
            END      
      
            -- Create a new PickDetail      
            INSERT INTO dbo.PickDetail (      
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,      
               UOMQTY, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,      
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,      
               PickDetailKey,      
               Status,       
               DropID,       
               QTY,      
               QTYMoved,       
               TrafficCop,      
               OptimizeCop)      
            SELECT      
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,      
               UOMQTY, LOC, ID, PackKey, UpdateSource, CartonGroup,      
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,      
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,      
               @cNewPickDetailKey,      
               Status,       
               DropID, -- ZG01      
               1,    -- QTY      
               1,    -- QTYMoved      
               NULL, -- TrafficCop      
               '1'   -- OptimizeCop      
            FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE PickDetailKey = @c_PDBorrow_Key      
    
            IF @@ERROR <> 0      
            BEGIN      
               SET @n_ErrNo = 184172      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- INS PKDtl Fail      
               GOTO RollBackTran      
            END      
      
            -- Split RefKeyLookup      
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PDBorrow_Key)      
            BEGIN      
               -- Insert into      
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)      
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey      
               FROM RefKeyLookup WITH (NOLOCK)       
               WHERE PickDetailKey = @c_PDBorrow_Key      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @n_ErrNo = 184173      
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- INS RefKeyFail      
           GOTO RollBackTran      
               END      
            END      
      
            -- Change borrow PickDetail      
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
               QTY = QTY - 1,      
               EditDate = GETDATE(),      
               EditWho  = SUSER_SNAME(),      
               Trafficcop = NULL      
            WHERE PickDetailKey = @c_PDBorrow_Key      
            IF @@ERROR <> 0      
            BEGIN      
               SET @n_ErrNo = 184174      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
         END      
                  
         -- Delete PickDetail with QTY=0      
         IF @n_PDBorrow_QTY = 1      
         BEGIN      
            DELETE PickDetail WHERE PickDetailKey = @c_PDBorrow_Key      
            IF @@ERROR <> 0      
            BEGIN      
               SET @n_ErrNo = 184175      
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail      
               GOTO RollBackTran      
            END      
         END      
      END      
      ELSE      
      BEGIN          
         SET @n_ErrNo = 184176      
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- Offset error       
         GOTO RollBackTran          
      END       
   END      
      
   Stamp_CaseID:  -- ZG01      
      
   IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)    -- ZG01      
       WHERE OrderKey = @c_Orderkey        
                     AND   DocType = 'N'        
                     AND   ConsigneeKey LIKE 'W%')        
      SET @n_IsMoveOrder = 1      
      
   -- Get carton info      
   SELECT TOP 1       
      @c_LabelNo = LabelNo       
   FROM dbo.PackDetail WITH (NOLOCK)          
   WHERE StorerKey = @c_Storerkey          
      AND PickSlipNo = @c_PickSlipNo          
      AND CartonNo = @n_CartonNo          
      AND SKU = @c_SKU      
      AND UPC = @c_Barcode      
   ORDER BY 1      
      
   -- Stamp pickdetail.caseid (to know which case in which pickdetail line)      
   DECLARE @cur_UpdPickDtl CURSOR      
   SET @cur_UpdPickDtl = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT PickDetailKey, QTY      
   FROM dbo.PickDetail WITH (NOLOCK)      
   WHERE OrderKey  = @c_OrderKey      
   AND   StorerKey  = @c_StorerKey      
   AND   SKU = @c_SKU      
   AND   Status < '9'      
   AND   DropID <> @c_LabelNo      
   AND   DropID = CASE WHEN @n_IsMoveOrder = 1 THEN '' ELSE DropID END      -- ZG01      
   ORDER BY PickDetailKey      
   OPEN @cur_UpdPickDtl      
   FETCH NEXT FROM @cur_UpdPickDtl INTO @c_PickDetailKey, @nPD_QTY      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      -- Exact match      
      IF @nPD_QTY = @nPack_QTY      
      BEGIN      
         -- Confirm PickDetail      
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
            DropID = @c_LabelNo,       
            TrafficCop = NULL      
         WHERE PickDetailKey = @c_PickDetailKey      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_ErrNo = 156612      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd Case Fail'      
            GOTO RollBackTran      
         END      
      
         SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance       
      END      
      -- PickDetail have less      
      ELSE IF @nPD_QTY < @nPack_QTY      
      BEGIN      
         -- Confirm PickDetail      
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
            DropID = @c_LabelNo,       
            TrafficCop = NULL      
         WHERE PickDetailKey = @c_PickDetailKey      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_ErrNo = 156613      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd Case Fail'      
            GOTO RollBackTran      
         END      
      
         SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance      
      END      
      -- PickDetail have more, need to split      
      ELSE IF @nPD_QTY > @nPack_Qty      
      BEGIN      
         -- Get new PickDetailkey      
         EXECUTE dbo.nspg_GetKey      
     'PICKDETAILKEY',      
            10 ,      
            @cNewPickDetailKey OUTPUT,      
            @b_success         OUTPUT,      
            @n_err             OUTPUT,      
            @c_errmsg          OUTPUT      
      
         IF @b_success <> 1      
         BEGIN      
            SET @n_ErrNo = 156614      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- 'Get PDKey Fail'      
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
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 0,  -- ZG01      
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,      
            @nPD_QTY - @nPack_QTY,       
            NULL, --TrafficCop,      
            '1'  --OptimizeCop      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE PickDetailKey = @c_PickDetailKey      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_ErrNo = 156615      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Ins PDtl Fail'      
            GOTO RollBackTran      
         END      
      
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
            Qty = @nPack_QTY,   -- deduct original qty      
            DropID = @c_LabelNo,       
            TrafficCop = NULL      
         WHERE PickDetailKey = @c_PickDetailKey      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_ErrNo = 156616      
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd Case Fail'      
            GOTO RollBackTran      
         END      
      
         SET @nPack_QTY = 0 -- Reduce balance        
      END      
      
      IF @nPack_QTY = 0       
         BREAK -- Exit      
      
      FETCH NEXT FROM @cur_UpdPickDtl INTO @c_PickDetailKey, @nPD_QTY      
   END      
         
   -- Check if pickslip already scan in and not yet insert transmitlog3 then start insert      
   IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)      
               WHERE PickSlipNo = @c_PickSlipNo      
               AND   ScanInDate IS NOT NULL      
               AND   TrafficCop = 'U')      
   BEGIN      
      IF NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)      
                        WHERE TableName = 'ScanInLog'      
                        AND   Key1 = @c_OrderKey      
                        AND   Key3 = @c_Storerkey)      
      BEGIN      
         EXECUTE dbo.nspGetRight      
            @c_Facility    = '',      
            @c_StorerKey   = @c_StorerKey,      
            @c_SKU         = '',      
            @c_ConfigKey   = 'ScanInLog',      
            @b_success     = @b_Success                OUTPUT,      
            @c_authority   = @c_Authority_ScanInLog    OUTPUT,      
            @n_err         = @n_ErrNo                  OUTPUT,      
            @c_errmsg      = @c_Errmsg                 OUTPUT      
      
         IF @b_Success <> 1      
         BEGIN      
            SET @n_ErrNo = 184178      
            SET @c_Errmsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'nspGetRightErr'      
            GOTO RollBackTran      
         End      
      
         IF @c_Authority_ScanInLog = '1'      
         BEGIN      
            EXEC dbo.ispGenTransmitLog3      
               @c_TableName      = 'ScanInLog',      
               @c_Key1           = @c_OrderKey,      
               @c_Key2           = '' ,      
               @c_Key3           = @c_StorerKey,      
               @c_TransmitBatch  = '',      
               @b_success        = @b_Success    OUTPUT,      
               @n_err            = @n_ErrNo      OUTPUT,      
               @c_errmsg         = @c_Errmsg     OUTPUT      
      
            IF @b_Success <> 1      
            BEGIN      
               SET @n_ErrNo = 184179      
               SET @c_Errmsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GenTLog3 Fail'      
               GOTO RollBackTran      
            End      
         END      
      END      
   END      
            
   COMMIT TRAN rdt_840SwapLot05      
   GOTO Quit      
         
   RollBackTran:        
      ROLLBACK TRAN rdt_840SwapLot05        
      
   Fail:        
   Quit:        
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
         COMMIT TRAN        
      
   Quit_WithoutTran:      
      
END -- End Procedure           

GO