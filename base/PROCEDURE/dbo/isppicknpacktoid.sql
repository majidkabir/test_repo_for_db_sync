SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Proc : ispPicknPackToID                                       */  
/* Creation Date: 26-Jun-2008                                           */  
/* Copyright: IDS                                                       */  
/* Written by: TING TUCK LUNG                                           */  
/*                                                                      */  
/* Purpose:  SOS#93101 - PICK-TO-ID ::                                  */  
/*                     Pick Instruction Generating & Report (PickSlip)  */  
/*                                                                      */  
/* Input Parameters: LoadKey                                            */  
/*                                                                      */  
/* Output Parameters: Report                                            */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: RCM report                                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 06-08-2008   Vanessa   Allow record display pickdetail.dropid = blank*/  
/*                        Report will show these records as a group     */  
/*                        SOS#112847                     -- (Vanessa01) */   
/* 20-08-2008   Vanessa   Allow to display OrderKey and Externorderkey  */  
/*                        SOS#114236                     -- (Vanessa02) */   
/* 01July2008   TLTING    SQL2005 Compatible                            */  
/* 25Nov 2008   TLTING    SOS118526 do not break for Pallat UOM(tlting01)*/
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/************************************************************************/  
  
CREATE PROC [dbo].[ispPicknPackToID] ( @c_LoadKey  NVARCHAR(10) )   
AS          
BEGIN       
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF                
  
   DECLARE      @c_PickHeaderKey NVARCHAR(10),          
      @n_row           int,          
      @n_err           int,          
      @n_continue      int,          
      @b_success       int,          
      @c_errmsg        NVARCHAR(255),          
      @n_StartTranCnt  int        
              
        
   Declare @c_debug  NVARCHAR(1)        
      , @c_PrintedFlag  NVARCHAR(1)        
        
   SET @c_debug = '0'        
        
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1          
          
   /* Start Modification */          
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order          
   SELECT @c_PrintedFlag = 'R'        
           
   IF @n_continue = 1 or @n_continue = 2            
   BEGIN          
      IF ISNULL(@c_LoadKey,'') = ''           
         Return          
        
      SELECT @c_PickHeaderKey = ''          
        
      IF NOT EXISTS(SELECT 1 FROM  PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = '7')           
      BEGIN          
         SELECT @c_PrintedFlag = 'N'             
         SELECT @b_success = 0          
        
         EXECUTE nspg_GetKey          
           'PICKSLIP',          
            9,             
            @c_PickHeaderKey    OUTPUT,          
            @b_success     OUTPUT,          
            @n_err         OUTPUT,          
            @c_errmsg      OUTPUT          
         
         IF @b_success <> 1          
         BEGIN          
            SELECT @n_continue = 3          
         END          
        
         IF @n_continue = 1 or @n_continue = 2          
         BEGIN          
            SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey          
         
            INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, Zone)          
            VALUES (@c_PickHeaderKey, @c_LoadKey, '7')          
                   
            SELECT @n_err = @@ERROR          
            
            IF @n_err <> 0           
            BEGIN          
               SELECT @n_continue = 3          
               SELECT @n_err = 63501          
               SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Into PICKHEADER Failed. (ispPicknPackToID)'   
            END          
         END -- @n_continue = 1 or @n_continue = 2          
      END  -- Not Exists PickHeader        
   END    -- @n_continue = 1 or @n_continue = 2        
          
   IF @n_continue = 1 or @n_continue = 2          
   BEGIN          
      Declare   @c_Storerkey   NVARCHAR(15)          
         , @c_PutawayZone NVARCHAR(10)        
         , @c_UOMType   NVARCHAR(10)        
         , @c_sku       NVARCHAR(20)        
         , @n_StdGrossWGT float        
         , @n_STDNETWGT   float        
         , @n_STDCube     float        
         , @n_QtyPick     float         
         , @c_BreakKey    NVARCHAR(100)              
         , @c_Prev_BreakKey    NVARCHAR(100)              
         , @c_CartonType   NVARCHAR(10)        
         , @n_MaxWeight    float        
         , @n_MaxCube      float        
         , @n_MaxQty       float        
         , @n_CumWeight    float        
         , @n_CumCube      float        
         , @n_CumQty       int        
         , @n_CurQty       int          
         , @n_SplitQty     int          
         , @c_CartonizationKey NVARCHAR(10)        
         , @c_PICKDETAILKey NVARCHAR(10)        
         , @c_New_PICKDETAILKey NVARCHAR(10)        
         , @c_DropID       NVARCHAR(18)        
         , @c_PickZone     NVARCHAR(10)        
         , @b_break        NVARCHAR(1)         
         , @n_Wgt_seq      int        
         , @c_UOMGroup     NVARCHAR(10)    -- tlting01
         , @n_PackCaseCnt  int
      
      SELECT @c_prev_BreakKey = ''        
      SELECT @n_CumWeight = 0        
      SELECT @n_CumCube   = 0        
      SELECT @n_CumQty    = 0        
      SELECT @n_CurQty    = 0        
      SELECT @b_break     = '0'        
      
      SET ROWCOUNT 1        
        
      WHILE (1=1)       
      BEGIN        
         SELECT @c_Storerkey = ''        
         SELECT @c_PutawayZone = ''        
         SELECT @c_UOMType = ''        
         SELECT @c_PICKDETAILKey = ''        
         SELECT @c_sku = ''        
         SELECT @n_StdGrossWGT = ''        
         SELECT @n_STDNETWGT = ''        
         SELECT @n_STDCube = ''        
         SELECT @n_QtyPick = 0        
         SELECT @c_CartonizationKey = ''
         SELECT @c_UOMGroup = ''    -- tlting01     
         SELECT @n_PackCaseCnt = 0            
        
         SELECT   @c_Storerkey = PICKDETAIL.Storerkey,         
            @c_PutawayZone = LOC.PutawayZone,       
            @c_UOMGroup    = CASE PICKDETAIL.UOM WHEN '1' THEN PICKDETAIL.UOM WHEN '2' THEN PICKDETAIL.UOM ELSE '3' END,          -- tlting01 
            @c_UOMType = CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END,        
            @c_PICKDETAILKey = PICKDETAIL.PICKDETAILKey,        
            @c_sku = SKU.SKU,        
            @n_StdGrossWGT = SKU.StdGrossWGT,        
            @n_STDNETWGT = SKU.STDNETWGT,        
            @n_STDCube = SKU.STDCube,        
            @n_QtyPick = ISNULL(PICKDETAIL.Qty,0),           
            @c_CartonizationKey = Cartonization.CartonizationKey,
            @n_PackCaseCnt = ISNULL(PACK.CaseCnt, 0)          
         FROM LOADPLAN (NOLOCK)           
         JOIN LOADPLANDETAIL  (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )           
         JOIN PICKDETAIL   (NOLOCK) ON ( PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey )           
         JOIN SKU     (NOLOCK) ON ( PICKDETAIL.Storerkey = SKU.StorerKey ) and           
                                  ( PICKDETAIL.Sku = SKU.Sku )           
         JOIN PICKHEADER   (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)           
         JOIN StorerConfig (NOLOCK) on ( StorerConfig.StorerKey = PICKDETAIL.StorerKey )        
                                   AND ( StorerConfig.ConfigKey = 'PickPackByID' )  -- 'PickPackByID'        
         JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = StorerConfig.SValue )        
                                    AND ( Cartonization.CartonType = CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )        
         JOIN PACK (NOLOCK) on ( PACK.PackKey = PICKDETAIL.PackKey )        
         JOIN LOC  (NOLOCK) ON ( LOC.LOC = PICKDETAIL.LOC )           
         WHERE LOADPLAN.LoadKey   >= @c_loadkey      
         AND   PICKDETAIL.STATUS < '5'          
         AND   ISNULL(PICKDETAIL.Qty,0) > 0        
         AND   LEN(ISNULL(PICKDETAIL.DropID, '')) = 0         
         AND   SKU.StdGrossWGT <= Cartonization.MaxWeight    -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1       
         AND   SKU.STDCube <=  Cartonization.Cube  
         AND   ( PICKDETAIL.UOM = '2' AND ISNULL(PACK.CaseCnt, 0) * SKU.StdGrossWGT <= Cartonization.MaxWeight )   -- Not process for wrong setup,  cartonization weight/cube is less then SKU QTY 1       
         AND   ( PICKDETAIL.UOM = '2' AND ISNULL(PACK.CaseCnt, 0) * SKU.STDCube <=  Cartonization.Cube )     -- (tlting01)  - avoid infinite loop for case break
         ORDER BY LOADPLAN.LoadKey,  LOC.PutawayZone,      
               CASE PICKDETAIL.UOM WHEN '1' THEN PICKDETAIL.UOM WHEN '2' THEN PICKDETAIL.UOM ELSE '3' END,  --tlting01                 
               CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END,          
               PICKDETAIL.LOC, ( PACK.CaseCnt * SKU.StdGrossWGT) desc,        
               ( PICKDETAIL.Qty * SKU.StdGrossWGT) desc, PICKDETAIL.SKU , PICKDETAIL.LOT        
  
         IF ISNULL(RTRIM(@c_LoadKey), '') = '' OR ISNULL (RTRIM(@c_Storerkey), '') = '' OR        
            ISNULL(RTRIM(@c_PutawayZone), '') = '' OR ISNULL(RTRIM(@c_UOMType), '') = ''        
         BEGIN        
            BREAK        
         END        
        
         IF @c_debug = '1'        
         BEGIN        
            SELECT '@c_LoadKey', @c_LoadKey , '@c_Storerkey', @c_Storerkey
            SELECT '@c_PutawayZone', @c_PutawayZone, '@c_UOMType', @c_UOMType, '@c_PICKDETAILKey', @c_PICKDETAILKey, '@c_CartonizationKey', @c_CartonizationKey        
            SELECT '@c_sku', @c_sku, '@n_StdGrossWGT', @n_StdGrossWGT, '@n_STDNETWGT', @n_STDNETWGT, '@n_STDCube', @n_STDCube, '@n_QtyPick', @n_QtyPick        
         END         
        
         SELECT @c_BreakKey = ISNULL(dbo.fnc_RTrim(@c_LoadKey), '') +'/'+ 
                         ISNULL(dbo.fnc_RTrim(@c_PutawayZone), '') +'/'+ ISNULL(RTRIM(@c_UOMGroup) , '') + '/' + ISNULL(dbo.fnc_RTrim(@c_UOMType), '')       

        
         IF @c_debug = '1'        
         BEGIN           
            SELECT '@c_prev_BreakKey', @c_prev_BreakKey, '@c_BreakKey', @c_BreakKey        
         END        
        
         IF @c_BreakKey <> @c_prev_BreakKey OR @c_UOMGroup = '1'        
         BEGIN        
            SELECT @c_prev_breakkey = @c_breakkey        
            Select @b_break = '1'        
         END        
        
         -- break DropID        
         IF  @b_break = '1'        
         BEGIN        
            SELECT @c_CartonType = Cartonization.CartonType,        
                  @n_MaxWeight = Cartonization.MaxWeight,        
                  @n_MaxCube = Cartonization.Cube,        
                  @n_MaxQty = Cartonization.MaxCount        
            FROM Cartonization With (nolock)         
            WHERE CartonizationKey = @c_CartonizationKey        
           
            IF @c_debug = '1'        
            BEGIN          
               SELECT '@c_CartonType', @c_CartonType,'@n_MaxWeight', @n_MaxWeight, '@n_MaxCube', @n_MaxCube, '@n_MaxQty',  @n_MaxQty         
            END        
        
            EXECUTE nspg_GetKey        
               'PICKToID',        
               10,        
               @c_DropID OUTPUT,           
               @b_success OUTPUT,        
               @n_err OUTPUT,        
               @c_errmsg OUTPUT        
  
            IF NOT @b_success = 1        
            BEGIN        
               BREAK        
            END        
        
            SELECT @n_CumWeight = 0        
            SELECT @n_CumCube   = 0        
            SELECT @n_CumQty    = 0        
            SELECT @n_CurQty    = 0        
            SELECT @b_break     = '0'        
         END    -- @b_break = '1'     
        
         SELECT @n_SplitQty = 0        
         SELECT @n_CurQty   = @n_QtyPick        
  
        -- UOM = 1 do not break pallet
         IF @c_UOMGroup <> '1' 
         BEGIN
   
            -- loop decs to fit in Pallet\Tote Weight\Cube\Qty limit        
            WHILE @n_CurQty > 0        
            BEGIN        
               IF @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT ) <= @n_MaxWeight AND        
                  @n_CumCube   + ( @n_CurQty * @n_STDCube )     <= @n_MaxCube   AND        
                  @n_CumQty    +  @n_CurQty                     <= @n_MaxQty              
               BEGIN        
                  SELECT @n_CumWeight = @n_CumWeight + ( @n_CurQty * @n_StdGrossWGT )         
                  SELECT @n_CumCube   = @n_CumCube   + ( @n_CurQty * @n_STDCube )         
                  SELECT @n_CumQty    = @n_CumQty    + @n_CurQty         
           
                  BREAK        
               END        
               ELSE        
               BEGIN        
                  -- tlting01
                  -- For case pack, break by case basis 
                  IF @c_UOMGroup = '2' AND @n_PackCaseCnt > 0
                  BEGIN
                     SELECT @n_CurQty = @n_CurQty - @n_PackCaseCnt       
                  END
                  ELSE
                  BEGIN
                     SELECT @n_CurQty = @n_CurQty - 1
                  END

                  SELECT @b_break = '1'  -- cause split PickDetail and break Drop ID        
               END        
            END  -- @n_CurQty > 0          
         END   -- @c_UOMGroup <> '1'    
        
         IF @c_debug = '1'        
         BEGIN          
            SELECT '@n_CurQty', @n_CurQty         
            SELECT '@n_CumWeight', @n_CumWeight, '@n_CumCube', @n_CumCube, '@n_CumQty', @n_CumQty         
         END        
        
         IF @n_CurQty > 0         
         BEGIN        
            IF @n_CurQty <> @n_QtyPick          
            BEGIN          
               SELECT @n_SplitQty = @n_QtyPick  - @n_CurQty        
           
               EXECUTE nspg_GetKey        
                  'PICKDETAILKEY',        
                  10,        
                  @c_New_PICKDETAILKey OUTPUT,           
                  @b_success OUTPUT,        
                  @n_err OUTPUT,        
                  @c_errmsg OUTPUT        
  
               IF NOT @b_success = 1        
               BEGIN        
                  BREAK        
               END        
           
               IF @c_debug = '1'        
               BEGIN          
                  SELECT '@c_New_PICKDETAILKey', @c_New_PICKDETAILKey        
               END        
            
               -- new pick item for remaining @n_SplitQty      
           
               INSERT PICKDETAIL        
                  ( PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,         
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )        
               SELECT @c_New_PICKDETAILKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                  Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,         
                  '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                  WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo        
               FROM PICKDETAIL WITH (NOLOCK)         
               WHERE PICKDETAILKey = @c_PICKDETAILKey        
  
               SELECT @n_err = @@ERROR        
                     
               IF @n_err <> 0         
               BEGIN        
                  SELECT @n_continue = 3        
                  SELECT @n_err = 63501        
                  SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) +   
                                    ': Insert Into PICKDETAIL Failed. (ispPicknPackToID)'        
                  BREAK      
               END        
      
               -- existing DROPID carton allow qty (@n_CurQty)   , remaining qty  (@n_SplitQty) next DropID      
               Update PICKDETAIL with (ROWLOCK)        
               Set Qty = @n_CurQty,        
                  UOMQTY = CASE UOM WHEN '6' THEN @n_CurQty ELSE UOMQty END ,       
                  DropID = @c_DropID,        
                  TrafficCop = NULL        
               WHERE PICKDETAILKey = @c_PICKDETAILKey        
  
               SELECT @n_err = @@ERROR        
               IF @n_err <> 0         
               BEGIN        
                SELECT @n_continue = 3        
                SELECT @n_err = 63501        
                SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'        
                BREAK      
               END        
            END   -- @n_CurQty <> @n_QtyPick     
            ELSE        
            BEGIN        
               -- Full Pickdetail item Qty for the DropID      
               Update PICKDETAIL with (ROWLOCK)        
               Set DropID = @c_DropID,        
                     TrafficCop = NULL        
               WHERE PICKDETAILKey = @c_PICKDETAILKey        
  
               SELECT @n_err = @@ERROR        
               IF @n_err <> 0         
               BEGIN        
                  SELECT @n_continue = 3        
                  SELECT @n_err = 63501        
                  SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Update PICKDETAIL Failed. (ispPicknPackToID)'        
                  BREAK      
               END        
            END        
         END   -- IF @n_CurQty > 0      
      END        
      SET ROWCOUNT 0        
  
      SELECT LOADPLAN.LoadKey,            
             LOADPLAN.AddDate,         
             LOADPLANDETAIL.Route,        
             LOADPLANDETAIL.Door,        
             LOADPLANDETAIL.Stop,        
             PICKHeader.PickHeaderKey,           
             LOC.PutawayZone,        
             PICKDETAIL.Storerkey,         
             PICKDETAIL.LOC,         
             PICKDETAIL.SKU,        
             PICKDETAIL.DropID,         
             CartonType = Convert(NVARchar(10), CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END),        
             Qty = SUM(ISNULL(PICKDETAIL.Qty,0)),           
             SKU.Descr,        
             StdGrossWGT = ISNULL(SKU.StdGrossWGT, 0),        
             STDCube = ISNULL(SKU.STDCube, 0),        
             Cartonization.CartonizationGroup,        
             PackCaseCnt = ISNULL(PACK.CaseCnt, 0),        
             PackPallet = ISNULL(PACK.Pallet, 0),        
             Lotattribute.Lottable01,        
             Lotattribute.Lottable02,        
             Lotattribute.Lottable03,        
             Lotattribute.Lottable04,        
             Orders.ConsigneeKey,        
             Orders.C_Company,        
             LOADPLANDETAIL.DeliveryDate,        
             UserID =   Convert(NVARCHAR(20), Suser_Sname()  ),      
             Wgt_seq = 0,  
             Orders.OrderKey,  -- (Vanessa02)  
             Orders.Externorderkey  -- (Vanessa02)  
      INTO #Output1      
      FROM LOADPLAN (NOLOCK)           
      JOIN LOADPLANDETAIL  (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )           
      JOIN PICKDETAIL   (NOLOCK) ON ( PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey )           
      JOIN SKU     (NOLOCK) ON ( PICKDETAIL.Storerkey = SKU.StorerKey ) and           
                               ( PICKDETAIL.Sku = SKU.Sku )           
      JOIN PICKHEADER   (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)           
      JOIN Orders (NOLOCK) on ( Orders.OrderKey = LOADPLANDETAIL.OrderKey )        
      JOIN StorerConfig (NOLOCK) on ( StorerConfig.StorerKey = PICKDETAIL.StorerKey )        
    AND ( StorerConfig.ConfigKey = 'PickPackByID' )  -- 'PickPackByID'        
      JOIN Cartonization (NOLOCK) on ( Cartonization.CartonizationGroup = StorerConfig.SValue )        
                                        AND ( Cartonization.CartonType = CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END )        
      JOIN PACK (NOLOCK) on ( PACK.PackKey = PICKDETAIL.PackKey )        
      JOIN LOC  (NOLOCK) ON ( LOC.LOC = PICKDETAIL.LOC )           
      JOIN Lotattribute  (NOLOCK) ON ( Lotattribute.Lot = PICKDETAIL.Lot )           
                                 AND ( Lotattribute.StorerKey = PICKDETAIL.StorerKey )           
                                 AND ( Lotattribute.SKU = PICKDETAIL.SKU )           
      WHERE LOADPLAN.LoadKey   = @c_loadkey          
      AND   ISNULL(PICKDETAIL.Qty,0) > 0        
      -- AND   LEN(ISNULL(PICKDETAIL.DropID, '')) > 0   -- (Vanessa01)      
      Group by  LOADPLAN.LoadKey,            
                LOADPLAN.AddDate,         
                LOADPLANDETAIL.Route,        
                LOADPLANDETAIL.Door,        
                LOADPLANDETAIL.Stop,        
                PICKHeader.PickHeaderKey,           
                LOC.PutawayZone,        
                PICKDETAIL.Storerkey,         
                PICKDETAIL.LOC,         
                PICKDETAIL.SKU,        
                PICKDETAIL.DropID,         
                Convert(NVARCHAR(10), CASE PICKDETAIL.UOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Pallet' ELSE 'Tote' END),        
                SKU.Descr,        
                SKU.StdGrossWGT,        
                SKU.STDCube,        
                Cartonization.CartonizationGroup,        
                PACK.CaseCnt,        
                PACK.Pallet,        
                Lotattribute.Lottable01,        
                Lotattribute.Lottable02,        
                Lotattribute.Lottable03,        
                Lotattribute.Lottable04,        
                Orders.ConsigneeKey,        
                Orders.C_Company,        
                LOADPLANDETAIL.DeliveryDate,  
                Orders.OrderKey,       -- (Vanessa02)  
                Orders.Externorderkey  -- (Vanessa02)        
      ORDER BY LOADPLAN.LoadKey,  LOC.PutawayZone, PICKDETAIL.DropID, PICKDETAIL.LOC, SKU.StdGrossWGT, PICKDETAIL.SKU         
      
      Select *    
      INTO #result    
      FROM #Output1 (NOLOCK)    
      ORDER BY LoadKey,  PutawayZone, DropID, StdGrossWGT * Qty desc, LOC, SKU         
    
      Set RowCount 1      
      
      Select @c_DropID = ''      
      
      While 1=1       
      BEGIN      
         Select @c_DropID = Min(DropID)      
         FROM #Output1   (NOLOCK)    
         Where  LoadKey  = @c_LoadKey    
         AND DropID > @c_DropID      
      
         IF ISNULL(@c_DropID, '')  = ''         
            Break      
              
         SELECT @n_Wgt_seq = 0      
       
         DECLARE cur1 CURSOR FOR        
         Select sku      
         FROM #Result       
         Where  LoadKey  = @c_LoadKey      
         AND DropID =  @c_DropID      
         FOR Update OF Wgt_seq      
      
         OPEN cur1        
         FETCH NEXT FROM cur1         
         INTO @c_sku        
  
         WHILE (@@fetch_status <> -1)        
         BEGIN        
            Select @n_Wgt_seq = @n_Wgt_seq + 1      
      
            Update #Result  with (Rowlock)    
            SET Wgt_seq = @n_Wgt_seq      
            WHERE CURRENT OF cur1      
      
            FETCH NEXT FROM cur1 INTO @c_sku        
         End        
         CLOSE cur1        
         DEALLOCATE cur1           
      END               
    
      Set RowCount 0      
      
      Select *      
      FROM #Result       
      ORDER BY LoadKey,  DropID  , loc, Wgt_seq    
    
      drop table  #Result    
      drop table  #Output1    
   END -- @n_continue = 1 or @n_continue = 2          
          
   IF @n_continue=3  -- Error Occured - Process And Return          
   BEGIN          
      execute nsp_logerror @n_err, @c_errmsg, "ispPicknPackToID"          
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN          
   END          
   ELSE          
   BEGIN          
      SELECT @b_success = 1          
      WHILE @@TRANCOUNT > @n_StartTranCnt          
      BEGIN          
         COMMIT TRAN          
      END          
      RETURN          
   END          
END /* main procedure */          
      

GO