SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispGenEOrderReplen03                               */  
/* Creation Date: 10-MAR-2023                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-21949 CN Converse release Ecom replenishment            */  
/*                                                                      */  
/* Called By: ECOM Release Dashboard                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 20-MAR-2023  NJOW     1.0  DEVOPS Combine Script                     */
/************************************************************************/   

CREATE   PROCEDURE [dbo].[ispGenEOrderReplen03]  
   @c_LoadKeyList NVARCHAR(1000),  
   @c_BatchNoList NVARCHAR(4000) = '',  
   @b_Debug       BIT = 0, 
   @b_Success     BIT = 1 OUTPUT,  
   @n_Err         INTEGER = 0 OUTPUT,  
   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_SKU                      NVARCHAR(20),
           @n_QtyOrdered               INT,
           @c_Facility                 NVARCHAR(5),
           @c_LOC                      NVARCHAR(10),
           @c_ToLOC                    NVARCHAR(10),   
           @c_LOT                      NVARCHAR(10),
           @c_ID                       NVARCHAR(20),  
           @n_CaseCnt                  INT, 
           @n_ReplenQty                INT, 
           @c_StorerKey                NVARCHAR(15), 
           @c_ReplenishmentGroup       NVARCHAR(10),
           @n_StartTCnt                INT, 
           @n_Continue                      INT,            
           @c_LoadKey                       NVARCHAR(10), 
           @c_PickDetailKey                 NVARCHAR(18), 
           @n_PickQty                       INT, 
           @b_ExistsFlag                    BIT, 
           @n_QtyAvaliable                  INT,
           @n_QtyAllocPick                  INT, 
           @n_QtyTakeFromPickLoc            INT, 
           @n_LooseQtyFromBulk              INT, 
           @n_FullCasePickQty               INT, 
           @c_MoveRefKey                    NVARCHAR(10),
           @c_ReplenishmentKey              NVARCHAR(10),
           @c_UOM                           NVARCHAR(10),
           @c_PackKey                       NVARCHAR(10), 
           @c_LoseID                        NVARCHAR(1), 
           @c_ToID                          NVARCHAR(20),  
           @n_QtyToTake                     INT,
           @n_QtyReplan                     INT = 0, 
           @n_PT_RowRef                     BIGINT = 0,
           @cFastPickLoc                    CHAR(1) = 'N',
           @c_DoReplenish                   CHAR(1), 
           @n_SplitQty                      INT, 
           @c_EOrderReplenByUCC             NVARCHAR(30), 
           @c_UCCNo                         NVARCHAR(20), 
           @n_UCCQty                        INT                
           
   DECLARE @c_AllowOverAllocations  NVARCHAR(1), 
           @c_ForceAllocLottable    NVARCHAR(1) = '0',
           @n_PickLocAvailableQty   INT = 0, 
           @c_LotAvailableQty       INT = 0,
           @n_LotCtn                INT = 0,
           @c_FromLOT               NVARCHAR(10) = '',
           @c_FromLOC               NVARCHAR(10) = '',
           @c_FromID                NVARCHAR(18) = '',
           @n_QtyAvailable          INT = 0, 
           @n_LocCapacity           INT = 0, 
           @n_ReplenToMaxQty        INT = 0 , 
           @n_SwapQty               INT = 0 ,
           @c_SwapPickDetailKey     NVARCHAR(10)  = '', 
           @c_NewPickDetailKey      NVARCHAR(10)  = '',
           @c_ForceLottableList     NVARCHAR(500) = '',
           @c_Lottable01            NVARCHAR(18)  = '',  
           @c_Lottable02            NVARCHAR(18)  = '',
           @c_Lottable03            NVARCHAR(18)  = '',
           @d_Lottable04            DATETIME,
           @c_SQLSelect             NVARCHAR(4000),
           @c_Lottable06            NVARCHAR(30) = '', 
           @c_Lottable07            NVARCHAR(30) = '', 
           @c_Lottable08            NVARCHAR(30) = '', 
           @c_Lottable09            NVARCHAR(30) = '', 
           @c_Lottable10            NVARCHAR(30) = '', 
           @c_Lottable11            NVARCHAR(30) = '', 
           @c_Lottable12            NVARCHAR(30) = '',
           @n_RemainingFullCase     INT = 0 
                    
   DECLARE
          @c_SQL                   NVARCHAR(MAX)
        , @c_SQLParms              NVARCHAR(MAX)
        , @c_WCS                   NVARCHAR(30)         
        , @c_PostGenEOrderReplenSP NVARCHAR(30)
   
   SET @c_Facility = ''  
   SET @n_Continue = 1 
   
   DECLARE @d_Trace_StartTime  DATETIME, 
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20), 
           @d_Trace_Step1      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),
           @c_Trace_Col4       NVARCHAR(20),           
           @c_UserName         NVARCHAR(20)
   
   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
   SET @c_Trace_Col4 = ''
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN;
           
   IF ISNULL(RTRIM(@c_LoadKeyList), '') <> ''
   BEGIN
      Declare @tloadkey TABLE  ( 
         Loadkey NVARCHAR(10) NOT NULL primary key,
         SeqNo INT identity(1,1)
        ) 
      
      IF CHARINDEX('|', @c_LoadKeyList) > 0 
      BEGIN
         INSERT INTO @tloadkey (Loadkey)
         SELECT ColValue 
         FROM [dbo].[fnc_DelimSplit]('|', @c_LoadKeyList)
         ORDER BY SeqNo     

         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78301
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Temp Table @tloadkey Failed! (ispGenEOrderReplen03)'        
            GOTO EXIT_SP
         END       
      END
      ELSE
      BEGIN
         INSERT INTO @tloadkey (Loadkey) VALUES (@c_LoadKeyList)
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78302
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Temp Table @tloadkey Failed! (ispGenEOrderReplen03)' 
            GOTO EXIT_SP      
         END
                  
      END     
      IF @b_Debug=1
      BEGIN
         SELECT '@tloadkey', * FROM @tloadkey
      END                                    
   END  
   ELSE
   BEGIN
      GOTO EXIT_SP 
   END    
 
   IF NOT EXISTS (SELECT 1 FROM @tloadkey AS tbn)
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>> Error: No Load Found!'        
      END
      GOTO EXIT_SP 
   END  
 
   Declare @tMoveLot TABLE  (
      LOT NVARCHAR(10) NOT NULL Primary key
      ) 
      
   DECLARE @tTaskBatchNo table   (
      
      TaskBatchNo NVARCHAR(10) not null Primary KEY,
      Seqno INT NOT NULL identity(1,1)
      )
 
   Declare @tTaskOrders TABLE  ( 
   Orderkey NVARCHAR(10) NOT NULL primary key ,
   Loadkey  NVARCHAR(10) NULL
   ) 


   SELECT TOP 1 
         @c_StorerKey = o.StorerKey, 
         @c_Facility  = o.Facility           
   FROM  ORDERS o WITH (NOLOCK) 
   JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey
   JOIN @tloadkey AS lk ON lk.LoadKey = lpd.LoadKey     

   SET @c_WCS = '0'

   SELECT @b_success = 0
   EXECUTE nspGetRight
            @c_facility       -- facility
         ,  @c_Storerkey      -- Storerkey
         ,  ''                -- Sku
         ,  'WCS'             -- Configkey
         ,  @b_success     OUTPUT
         ,  @c_WCS         OUTPUT
         ,  @n_err         OUTPUT
         ,  @c_errmsg      OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 78329
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (ispGenEOrderReplen03)'
      GOTO EXIT_SP      
   END
   
   SELECT @b_success = 0
   EXECUTE nspGetRight
            @c_facility       -- facility
         ,  @c_Storerkey      -- Storerkey
         ,  ''                -- Sku
         ,  'EOrderReplenByUCC'   -- Configkey
         ,  @b_success     OUTPUT
         ,  @c_EOrderReplenByUCC   OUTPUT
         ,  @n_err         OUTPUT
         ,  @c_errmsg      OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 78330
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (ispGenEOrderReplen03)'
      GOTO EXIT_SP      
   END                                
              
   IF ISNULL(RTRIM(@c_BatchNoList), '') <> ''
   BEGIN    
      IF CHARINDEX('|', @c_BatchNoList) > 0 
      BEGIN
         INSERT INTO @tTaskBatchNo (TaskBatchNo)
         SELECT ColValue 
         FROM [dbo].[fnc_DelimSplit]('|', @c_BatchNoList)
         ORDER BY SeqNo
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78303
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Temp Table @tTaskBatchNo Failed! (ispGenEOrderReplen03)'
            GOTO EXIT_SP         
         END
      END
      ELSE 
      BEGIN
         INSERT INTO @tTaskBatchNo (TaskBatchNo)
         VALUES (@c_BatchNoList)
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78304
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Temp Table @tTaskBatchNo Failed! (ispGenEOrderReplen03)'
            GOTO EXIT_SP         
         END         
      END 
    
      IF @b_Debug=1
      BEGIN
         SELECT '@tTaskBatchNo Before', * FROM @tTaskBatchNo
      END  
      
      IF @c_WCS = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM @tTaskBatchNo TBN 
                     JOIN PACKTASK PT WITH (NOLOCK) ON PT.TaskBatchNo = TBN.TaskBatchNo 
                     WHERE PT.ReplenishmentGroup IS NOT NULL
                     AND   PT.ReplenishmentGroup <> '' 
                    )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 78330
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Replenishment are generated for the selected Task.'
                         +' Generate Replenishment Abort.(ispGenEOrderReplen03)'
            GOTO EXIT_SP  
         END
      END
               
      DELETE TBN
      FROM @tTaskBatchNo TBN 
      JOIN PackTask PT WITH (NOLOCK) ON PT.TaskBatchNo = TBN.TaskBatchNo 
      WHERE PT.ReplenishmentGroup IS NOT NULL
      AND   PT.ReplenishmentGroup <> ''   
      AND   EXISTS(SELECT 1 FROM LoadPlanDetail AS lpd WITH (NOLOCK)
                   JOIN @tloadkey AS lk  ON lk.LoadKey = lpd.LoadKey
                   WHERE lpd.OrderKey = PT.Orderkey) 
      IF @b_Debug=1
      BEGIN
         SELECT '@tTaskBatchNo Delete', * FROM @tTaskBatchNo
      END                     
   END
   ELSE 
   BEGIN 
      IF @c_WCS = '1'
      BEGIN
         IF EXISTS ( SELECT 1  
                     FROM PACKTASK PT WITH (NOLOCK)  
                     JOIN LOADPLANDETAIL AS lpd WITH (NOLOCK) on lpd.Orderkey = pt.Orderkey 
                     JOIN @tloadkey AS lk  ON lk.LoadKey = lpd.LoadKey
                     WHERE PT.ReplenishmentGroup IS NOT NULL
                     AND   PT.ReplenishmentGroup <> '' 
                    )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 78331
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Replenishment are generated for the selected Loadkey.'
                         +' Generate Replenishment Abort.(ispGenEOrderReplen03)'
            GOTO EXIT_SP   
         END
      END
      
      INSERT INTO @tTaskBatchNo (TaskBatchNo)
      SELECT DISTINCT pt.TaskBatchNo  
      FROM PackTask AS pt WITH (NOLOCK) 
      JOIN LoadPlanDetail AS lpd WITH (NOLOCK) on lpd.Orderkey = pt.Orderkey 
      JOIN @tloadkey AS lk  ON lk.LoadKey = lpd.LoadKey
      WHERE (pt.ReplenishmentGroup = '' OR pt.ReplenishmentGroup IS NULL) 
      IF @@ERROR <> 0 
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 78306
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Temp Table @tTaskBatchNo Failed! (ispGenEOrderReplen03)'
         GOTO EXIT_SP         
      END
   END

   IF NOT EXISTS (SELECT 1 FROM @tTaskBatchNo AS tbn)
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>  Error: No TaskBatchNo Found!'               
      END      
      GOTO EXIT_SP 
   END   

   INSERT INTO @tTaskOrders (Orderkey, Loadkey )
   SELECT DISTINCT PT.OrderKey , lpd.LoadKey
   FROM  @tTaskBatchNo tbn     
      JOIN PackTask AS PT WITH (NOLOCK) ON tbn.TaskBatchNo = PT.TaskBatchNo    
      JOIN LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.Orderkey = PT.Orderkey   
      JOIN @tloadkey AS lk  ON lk.LoadKey = lpd.LoadKey

 
   SET @c_AllowOverAllocations = '0'

   SELECT @b_success = 0
   EXECUTE nspGetRight
            @c_facility,    -- facility
            @c_Storerkey,   -- Storerkey
            '',             -- Sku
            'ALLOWOVERALLOCATIONS', -- Configkey
            @b_success              OUTPUT,
            @c_AllowOverAllocations OUTPUT,
            @n_err                  OUTPUT,
            @c_errmsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78307
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (ispGenEOrderReplen03)'
      GOTO EXIT_SP      
   END

   SET @c_ForceAllocLottable = '0'

   SELECT @b_success = 0
   EXECUTE nspGetRight
            @c_facility,    -- facility
            @c_Storerkey,   -- Storerkey
            '',             -- Sku
            'ForceAllocLottable', -- Configkey
            @b_success              OUTPUT,
            @c_ForceAllocLottable   OUTPUT,
            @n_err                  OUTPUT,
            @c_errmsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78308
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight ForceAllocLottable Failed! (ispGenEOrderReplen03)'
      GOTO EXIT_SP      
   END

   IF @c_ForceAllocLottable = '1'
   BEGIN
      SELECT TOP 1 @c_ForceLottableList = NOTES
      FROM CODELKUP (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Listname = 'FORCEALLOT'

      IF ISNULL(@c_ForceLottableList,'') = ''
         SET @c_ForceLottableList = 'LOTTABLE01,LOTTABLE02,LOTTABLE03'     
   END
   ELSE 
      SET @c_ForceLottableList = ''

               
   BEGIN TRAN           
   EXECUTE nspg_GetKey
           @keyname       = 'REPLENISHGROUP',
           @fieldlength   = 10,
           @keystring     = @c_ReplenishmentGroup OUTPUT,
           @b_success     = @b_success   OUTPUT,
           @n_err         = @n_err       OUTPUT, 
           @c_errmsg      = @c_errmsg    OUTPUT
   IF NOT @b_success = 1
   BEGIN
      SELECT @n_continue = 3
      GOTO EXIT_SP 
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN
         BEGIN TRAN
      END
   END

   IF @b_Debug = 1
   BEGIN
      PRINT 'Replenishment Group: ' + @c_ReplenishmentGroup 
   END
   
   -- Update PackTask Replenishment Group
   DECLARE @n_RowRef BIGINT  
  
   --Find or combine full UCC and update UCC
   IF @n_continue IN(1,2) AND @c_EOrderReplenByUCC = '1' 
   BEGIN
   	  BEGIN TRAN
   	  	
   	  --Get pick qty for single order not yet assign with UCC. 
      DECLARE CUR_Bulk_UCCReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT P.Storerkey, o.Facility, P.Sku, P.LOC, P.LOT, P.ID, P.UOM, SUM(P.Qty) OrderQty 
         FROM PICKDETAIL AS p WITH (NOLOCK) 
         JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey    
         JOIN ORDERS AS o WITH(NOLOCK) ON o.Orderkey = PT.Orderkey 
         JOIN SKUxLOC AS sl WITH (NOLOCK) ON  SL.Storerkey = P.Storerkey AND SL.Sku = P.Sku AND SL.Loc = P.Loc AND SL.LocationType NOT IN ('PICK', 'CASE')
         JOIN LOC AS l WITH (NOLOCK) ON l.Loc = P.Loc AND l.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK', 'FASTPICK') AND l.Facility = o.Facility 
         LEFT JOIN UCC (NOLOCK) ON P.Lot = UCC.Lot AND P.Loc = UCC.Loc AND P.Id = UCC.Id AND UCC.UCCNo = P.DropID      
         WHERE P.[Status] = '0' 
         AND P.UOM IN ('2','6','7') 
         AND O.ECOM_SINGLE_Flag = 'S'
         AND UCC.UCCNo IS NULL
         GROUP BY P.Storerkey, o.Facility, P.Sku, P.LOC, P.LOT, P.ID, P.UOM 
         ORDER BY P.UOM, P.Sku
         
      OPEN CUR_Bulk_UCCReplen
      
      FETCH NEXT FROM CUR_Bulk_UCCReplen INTO @c_StorerKey, @c_Facility, @c_SKU, @c_LOC, @c_LOT, @c_ID, @c_UOM, @n_QtyOrdered

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 --Get ucc available
         DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT UCCNo, Qty
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU
            AND Lot = @c_Lot
            AND Loc = @c_Loc
            AND ID = @c_Id
            AND Status < '3'
            AND Qty <= @n_QtyOrdered
            ORDER BY UCC.Qty, UCC.UCCNo

         OPEN CUR_UCC
         
         FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty         
            
         WHILE @@FETCH_STATUS = 0 AND @n_QtyOrdered > 0 AND @n_continue IN(1,2)
         BEGIN         	
         	  IF @n_QtyOrdered < @n_UCCQty
         	     BREAK

            --Assing UCC to pick
            DECLARE CUR_UCCPick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT P.Pickdetailkey, P.Qty 
               FROM PICKDETAIL AS p WITH (NOLOCK) 
               JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey 
               JOIN ORDERS AS o WITH(NOLOCK) ON o.Orderkey = PT.Orderkey 
               JOIN SKUxLOC AS sl WITH (NOLOCK) ON  SL.Storerkey = P.Storerkey AND SL.Sku = P.Sku AND SL.Loc = P.Loc AND SL.LocationType NOT IN ('PICK', 'CASE')
               JOIN LOC AS l WITH (NOLOCK) ON l.Loc = P.Loc AND l.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK', 'FASTPICK') AND l.Facility = o.Facility 
               LEFT JOIN UCC (NOLOCK) ON P.Lot = UCC.Lot AND P.Loc = UCC.Loc AND P.Id = UCC.Id AND UCC.UCCNo = P.DropID      
               WHERE P.[Status] = '0'                
               AND P.UOM = @c_UOM 
               AND UCC.UCCNo IS NULL
               AND P.Lot = @c_Lot
               AND P.Loc = @c_Loc
               AND P.Id = @c_ID         	   
         	  
            OPEN CUR_UCCPick
         
            FETCH NEXT FROM CUR_UCCPick INTO @c_Pickdetailkey, @n_PickQty         
            
            WHILE @@FETCH_STATUS = 0 AND @n_UCCQty > 0 AND @n_continue IN(1,2)
            BEGIN            	  
            	 IF @n_UCCQty >= @n_PickQty
            	 BEGIN
            	 	  UPDATE PICKDETAIL WITH (ROWLOCK)
            	 	  SET DropID = @c_UCCNo,
            	 	      UOM = '2',
            	 	      TrafficCop = NULL
            	 	  WHERE Pickdetailkey = @c_Pickdetailkey

                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78315
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                  END 
            	 	  
            	 	  SET @n_UCCQty = @n_UCCQty - @n_PickQty               	 	                            	 	              	 	      
              	  SET @n_QtyOrdered =  @n_QtyOrdered - @n_PickQty 
            	 END
            	 ELSE
            	 BEGIN
                  SET @c_NewPickDetailKey = ''
                                       
                  EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',   
                     10 ,  
                     @c_NewPickDetailKey  OUTPUT,  
                     @b_success        OUTPUT,  
                     @n_err            OUTPUT,  
                     @c_errmsg         OUTPUT  
                  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_Err = 63885  
                     SET @c_ErrMsg = 'Get Pickdetail Key'
                     SET @n_Continue = 3
                  END 
                                    
                  SET @n_SplitQty = @n_PickQty - @n_UCCQty

                  INSERT INTO dbo.PICKDETAIL
                     (
                      PickDetailKey    ,CaseID           ,PickHeaderKey
                     ,OrderKey         ,OrderLineNumber  ,Lot
                     ,Storerkey        ,Sku              ,AltSku
                     ,UOM              ,UOMQty           ,Qty
                     ,QtyMoved         ,STATUS           ,DropID
                     ,Loc              ,ID               ,PackKey
                     ,UpdateSource     ,CartonGroup      ,CartonType
                     ,ToLoc            ,DoReplenish      ,ReplenishZone
                     ,DoCartonize      ,PickMethod       ,WaveKey
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                     ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                     ,Channel_ID   
                     )
                  SELECT @c_NewPickDetailKey  AS PickDetailKey
                        ,CaseID           ,PickHeaderKey    ,OrderKey
                        ,OrderLineNumber  ,@c_Lot           ,Storerkey
                        ,Sku              ,AltSku           ,@c_UOM
                        ,UOMQty           ,@n_SplitQty
                        ,QtyMoved         ,[STATUS]         ,DropID       
                        ,Loc   		        ,ID               ,PackKey      
                        ,UpdateSource     ,CartonGroup      ,CartonType      
                        ,@c_PickDetailKey ,DoReplenish	   ,ReplenishZone='SplitToUCC'      
                        ,DoCartonize      ,PickMethod       ,WaveKey      
                        ,EffectiveDate    ,TrafficCop   		,ArchiveCop      
                        ,'9'              ,ShipFlag         ,PickSlipNo   
                        ,Channel_ID   
                  FROM   dbo.PickDetail WITH (NOLOCK)
                  WHERE  PickDetailKey = @c_PickDetailKey 

                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78313
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispGenEOrderReplen03)'
                  END                   
                                    
                  UPDATE PickDetail WITH (ROWLOCK)
                  SET UOM = '2', 
                      DropID = @c_UCCNo,   
                      Qty = @n_UCCQty, 
                      TrafficCop = NULL,
                      EditDate = GETDATE(), 
                      EditWho = SUSER_SNAME(),
                      ReplenishZone='SplitFrUCC'
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78315
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                  END 
                   
                  SET @n_QtyOrdered = @n_QtyOrdered - @n_UCCQty 
                  SET @n_UCCQty = 0                   
            	 END
            	             	 
               FETCH NEXT FROM CUR_UCCPick INTO @c_Pickdetailkey, @n_PickQty         
            END
            CLOSE CUR_UCCPick
            DEALLOCATE CUR_UCCPick
            
            --Update UCC
            IF @n_UCCQty = 0
            BEGIN
               UPDATE UCC WITH (ROWLOCK)
               SET Status = '5'
               WHERE UCCNo = @c_UCCNo
               AND Status < '3'

               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78315
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Failed! (ispGenEOrderReplen03)'
               END                               
            END
         	         	              	           	  
            FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty         
         END
         CLOSE CUR_UCC
         DEALLOCATE CUR_UCC
         
         IF @n_QtyOrdered > 0 AND @c_UOM = '2'
         BEGIN
         	  --UPDATE TO UOM 2 to 6 if can't find UCC
         	    DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT P.Pickdetailkey 
               FROM PICKDETAIL AS p WITH (NOLOCK) 
               JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey   
               JOIN ORDERS AS o WITH(NOLOCK) ON o.Orderkey = PT.Orderkey 
               JOIN SKUxLOC AS sl WITH (NOLOCK) ON  SL.Storerkey = P.Storerkey AND SL.Sku = P.Sku AND SL.Loc = P.Loc AND SL.LocationType NOT IN ('PICK', 'CASE')
               JOIN LOC AS l WITH (NOLOCK) ON l.Loc = P.Loc AND l.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK', 'FASTPICK') AND l.Facility = o.Facility 
               LEFT JOIN UCC (NOLOCK) ON P.Lot = UCC.Lot AND P.Loc = UCC.Loc AND P.Id = UCC.Id AND UCC.UCCNo = P.DropID      
               WHERE P.[Status] = '0'                
               AND P.UOM = @c_UOM 
               AND UCC.UCCNo IS NULL
               AND P.Lot = @c_Lot
               AND P.Loc = @c_Loc
               AND P.Id = @c_ID         	   
         	  
            OPEN CUR_Pick
         
            FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
            BEGIN            	  
               UPDATE PickDetail WITH (ROWLOCK)
               SET UOM = '6', 
                   TrafficCop = NULL,
                   EditDate = GETDATE(), 
                   EditWho = SUSER_SNAME(),
                   ReplenishZone='ChgUOM2to6'
               WHERE PickDetailKey = @c_PickDetailKey
               
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78315
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
               END 
                     
               FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey
            END
            CLOSE CUR_Pick
            DEALLOCATE CUR_Pick
         END
                  	      	
         FETCH NEXT FROM CUR_Bulk_UCCReplen INTO @c_StorerKey, @c_Facility, @c_SKU, @c_LOC, @c_LOT, @c_ID,  @c_UOM, @n_QtyOrdered
      END
      CLOSE CUR_Bulk_UCCReplen
      DEALLOCATE CUR_Bulk_UCCReplen
      
      IF @n_continue = 3
         GOTO EXIT_SP
      
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN
         BEGIN TRAN
      END       	 
   END --@c_EOrderReplenByUCC = '1' 

   -- Get Lose Pick From Bulk for ECOM Single Order
   DECLARE CUR_Bulk_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT P.Storerkey, o.Facility, P.Sku, P.LOC, P.LOT, P.ID, SUM(P.Qty) OrderQty, PK.CaseCnt, 
          PK.PackKey, PK.PackUOM3                    
   FROM PICKDETAIL AS p WITH (NOLOCK) 
   JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey      
   JOIN ORDERS AS o WITH(NOLOCK) ON o.Orderkey = PT.Orderkey 
   JOIN PACK AS PK WITH (NOLOCK) ON PK.PackKey = P.PackKey 
   JOIN SKUxLOC AS sl WITH (NOLOCK) 
         ON  SL.Storerkey = P.Storerkey 
         AND SL.Sku = P.Sku 
         AND SL.Loc = P.Loc
         AND SL.LocationType NOT IN ('PICK', 'CASE')
   JOIN LOC AS l WITH (NOLOCK) 
         ON l.Loc = P.Loc
         AND l.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK', 'FASTPICK') 
         AND l.Facility = o.Facility 
   WHERE (PK.CaseCnt > 0 OR @c_EOrderReplenByUCC = '1') 
   AND   P.[Status] = '0'   
   AND   P.UOM IN ('6','7') 
   AND   l.LocationType = 'OTHER' --CONV
   AND   l.LocationCategory = 'BULK'  --CONV
   AND   l.Hostwhcode = 'SA'  --CONV
   GROUP BY PT.LoadKey, P.Storerkey, o.Facility, P.Sku, P.LOC, P.LOT, P.ID, PK.CaseCnt, PK.PackKey, PK.PackUOM3 
   
   OPEN CUR_Bulk_Replenishment
   
   FETCH NEXT FROM CUR_Bulk_Replenishment INTO 
      @c_StorerKey, @c_Facility, @c_SKU, @c_LOC, @c_LOT, @c_ID, @n_QtyOrdered, @n_CaseCnt, @c_PackKey, @c_UOM 
   
   WHILE @@FETCH_STATUS = 0
   BEGIN    
      BEGIN TRAN
      
      IF @c_EOrderReplenByUCC = '1' 
         SET @n_CaseCnt = 0                  

      SET @c_ToLOC = ''
      SELECT TOP 1 
         @c_ToLOC = SKUxLOC.LOC 
      FROM SKUxLOC WITH (NOLOCK)
      JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SKUxLOC.Loc AND L.Facility = @c_Facility 
      WHERE SKUxLOC.StorerKey = @c_StorerKey 
      AND   SKUxLOC.SKU = @c_SKU 
      AND   SKUxLOC.LocationType IN ('PICK', 'CASE')
      AND   L.LocationFlag = 'NONE'    
      
      IF @c_ToLOC = ''
      BEGIN
         SELECT TOP 1 
                @c_ToLOC = l.LOC
         FROM   LOC AS l WITH (NOLOCK) 
         JOIN   SKUxLOC AS sl WITH (NOLOCK) ON SL.Loc = l.Loc 
         WHERE  SL.StorerKey = @c_StorerKey 
         AND    SL.Sku = @c_SKU 
         AND    l.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')
         AND    L.Facility = @c_Facility
         AND    L.LocationFlag = 'NONE'  
      END 
      IF @c_ToLOC = ''
      BEGIN
         SELECT TOP 1 @c_ToLOC = s.[Data] 
         FROM SKUConfig AS s WITH (NOLOCK) 
         JOIN LOC AS l WITH(NOLOCK) ON s.[Data] = L.Loc 
         WHERE s.StorerKey = @c_StorerKey 
         AND   s.SKU = @c_SKU 
         AND   s.ConfigType = 'DefaultDPP' 
         AND   l.Facility = @c_Facility 
         AND   L.LocationFlag = 'NONE'  
         
         IF @c_ToLOC <> ''
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM LOC AS l WITH (NOLOCK)
                          WHERE l.Loc = @c_ToLOC
                          AND   l.LocationType IN ('DYNPICKP', 'DYNPICKR','DYNPPICK')
                          AND   l.LocationFlag = 'NONE')  
            BEGIN
               SET @c_ToLOC = ''
            END                      
         END  
      END                  
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>  @c_SKU: ' +  RTRIM(@c_SKU) + ', LOT: ' + @c_LOT + ', LOC: ' + @c_LOC + ', ID:' + RTRIM(@c_ID) + 
               ',To Loc: ' + @c_ToLOC 
         PRINT '      Ordered Qty:' + CAST(@n_QtyOrdered AS VARCHAR(10))  
         PRINT '      CaseCnt: ' + CAST(@n_CaseCnt AS VARCHAR(10))
      END
      
      IF @c_ToLOC <> ''
      BEGIN        
         SET @n_QtyAvaliable = 0 
         SET @n_QtyAllocPick = 0 
         SET @n_QtyTakeFromPickLoc = 0
         SET @n_QtyReplan = 0  
         
         SET @c_LoseID = '0' 
         SELECT @c_LoseID = LOC.LoseId 
         FROM   LOC WITH (NOLOCK) 
         WHERE  LOC = @c_ToLOC         

         IF @c_LoseID = '1'
            SET @c_toID = ''
         ELSE 
            SET @c_ToID = @c_ID 
                              
         SELECT @n_QtyAvaliable = (lli.Qty - lli.QtyPicked - lli.QtyAllocated - lli.QtyReplen) + @n_QtyOrdered, 
                @n_QtyAllocPick = lli.QtyAllocated, 
                @n_QtyReplan = lli.QtyReplen 
         FROM   LOTxLOCxID AS lli WITH (NOLOCK)
         WHERE  LOT = @c_LOT 
         AND    LOC = @c_LOC
         AND    ID  = @c_ID

         SET @n_FullCasePickQty = 0 
         SET @n_ReplenQty = 0 
         
         IF @n_CaseCnt > 0     
            SET @n_FullCasePickQty = FLOOR( @n_QtyOrdered / @n_CaseCnt ) * @n_CaseCnt
         ELSE 
            SET @n_FullCasePickQty = 0 
             
         SET @n_ReplenQty =  @n_QtyOrdered - @n_FullCasePickQty
         IF @n_ReplenQty > 0 AND @n_ReplenQty < @n_CaseCnt 
         BEGIN
            SET @n_LooseQtyFromBulk = @n_ReplenQty 
            SET @n_ReplenQty = @n_CaseCnt             
         END
                              
         IF @b_Debug = 1
         BEGIN
            PRINT '      Available Qty:' + CAST(@n_QtyAvaliable AS VARCHAR(10)) + 
                  ', AllocPick Qty:' + CAST(@n_QtyAllocPick AS VARCHAR(10)) + 
                  ', FullCasePickQty:' + CAST(@n_FullCasePickQty AS VARCHAR(10)) +
                  ', ReplenQty:' + CAST(@n_ReplenQty AS VARCHAR(10))
            PRINT '' 
         END     
         
         DECLARE CUR_PICKDETAIL_RECORDS CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT P.PickDetailKey, P.Qty, 
                CASE WHEN TBN.SeqNo IS NULL OR LK.SeqNo IS NULL 
                     THEN 0
                     ELSE 1
                END ExistsFlag, 
                PT.RowRef 
         FROM PICKDETAIL AS p WITH (NOLOCK) 
         INNER JOIN LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.Orderkey = P.Orderkey          
         INNER JOIN PackTask AS PT WITH (NOLOCK) ON PT.OrderKey = P.OrderKey
         INNER JOIN @tTaskBatchNo AS tbn  ON tbn.TaskBatchNo = PT.TaskBatchNo 
         INNER JOIN @tloadkey AS lk  ON lk.LoadKey = lpd.LoadKey 
         WHERE P.Storerkey = @c_StorerKey
         AND   P.Sku = @c_SKU 
         AND   P.LOC = @c_LOC 
         AND   P.LOT = @c_LOT 
         AND   P.ID  = @c_ID     
         AND   P.[Status] < '5' 
         AND   P.ShipFlag NOT IN ('P','Y') 
         AND   P.UOM IN ('6','7')
         AND  (P.MoveRefKey = '' OR P.MoveRefKey IS NULL)
         ORDER BY ExistsFlag DESC, P.PickDetailKey          
         
         OPEN CUR_PICKDETAIL_RECORDS
         
         FETCH NEXT FROM CUR_PICKDETAIL_RECORDS INTO @c_PickDetailKey, @n_PickQty, @b_ExistsFlag, @n_PT_RowRef
         
         WHILE @@FETCH_STATUS = 0
         BEGIN   
            IF @b_Debug = 1
            BEGIN
               PRINT '  >>  PickDetailKey: ' +  @c_PickDetailKey + ', Qty:' + CAST(@n_PickQty AS VARCHAR(10)) +
                     ', ExistsFlag: ' + CAST(@b_ExistsFlag AS VARCHAR(1))                 
            END                                     
            
            IF @n_FullCasePickQty > 0 
            BEGIN                            
               UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET UOM = '2', 
                      TrafficCop = NULL,
                      EditWho = SUSER_SNAME(),
                      EditDate = GETDATE(),
                      ReplenishZone = 'FullCtn'  
               WHERE PickDetailKey = @c_PickDetailKey  
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78309
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Updating PickDetail Failed! (ispGenEOrderReplen03)'
                  GOTO EXIT_SP         
               END
                     
               SET @n_FullCasePickQty = @n_FullCasePickQty - @n_PickQty          
            END                              
            ELSE IF @n_ReplenQty > 0 AND @n_FullCasePickQty = 0 
            BEGIN             
               -- If Destination Location already have inventory availble
               SET @n_PickLocAvailableQty = 0 
               
               SELECT @n_PickLocAvailableQty = SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked 
               FROM SKUxLOC WITH (NOLOCK) 
               JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc 
               WHERE SKUxLOC.StorerKey = @c_StorerKey 
               AND   SKUxLOC.Sku = @c_SKU 
               AND   SKUxLOC.LOC = @c_ToLOC 
               AND   LOC.Facility = @c_Facility 
               AND   (SKUxLOC.LocationType IN ('CASE', 'PICK') OR LOC.LocationType IN ('DYNPICKP', 'DYNPICKR'))                            
               AND   SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked > 0
                           
               --IF @n_PickLocAvailableQty >= @n_PickQty 
               BEGIN                    
                  SET @c_LotAvailableQty = 0 
                  SET @n_LotCtn = 0 
                                                         
                  SELECT @c_LotAvailableQty = lli.Qty - lli.QtyAllocated - lli.QtyPicked, 
                         @n_LotCtn = 1  
                  FROM LOTxLOCxID AS lli WITH(NOLOCK)
                  WHERE lli.Lot = @c_LOT 
                  AND lli.Loc = @c_ToLOC 
                  AND lli.Id = ''
                                
                  IF @c_LotAvailableQty < @n_PickQty 
                  BEGIN
                     IF @c_AllowOverAllocations = '1'
                     BEGIN
                        IF @n_LotCtn = 0 
                        BEGIN
                           INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey, Sku, Qty)
                           VALUES (@c_LOT, @c_ToLOC, '', @c_StorerKey, @c_SKU, 0) 
                           IF @@ERROR <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @n_err = 78310
                              SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Updating LOTxLOCxID Failed! (ispGenEOrderReplen03)'
                              GOTO EXIT_SP         
                           END
                        END                                                                           
                     END
                     IF NOT EXISTS (SELECT 1 FROM @tMoveLot WHERE LOT = @c_LOT)
                     BEGIN
                        INSERT INTO @tMoveLot ( LOT )
                        VALUES ( @c_LOT )
                     END
                     --ELSE 
                     -- GOTO CREATE_REPLENISHMENT
                  END

                  IF @b_Debug = 1
                  BEGIN
                     PRINT '      Take from Pick LOC: ' + @c_ToLOC + ' Qty Avaiable: ' + CAST(@n_PickLocAvailableQty AS VARCHAR(10)) + ' LotAvailableQty: '+CAST(@c_LotAvailableQty AS VARCHAR(10)) + ' PickQty: ' + CAST(@n_PickQty AS VARCHAR(10))        
                  END   
                                                                           
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET LOC = @c_ToLOC, 
                         ID = '', -- Loose ID 
                         UOM = CASE WHEN @c_LotAvailableQty < @n_PickQty THEN '7' ELSE '6' END, -- SWT02
                         EditDate = GETDATE(), 
                         EditWho = SUSER_SNAME(), 
                         ToLoc = LOC, -- Backup Original Loc
                         ReplenishZone = 'ChgPick',
                         DoReplenish = CASE WHEN @c_LotAvailableQty < @n_PickQty THEN 'N' ELSE 'Y' END 
                  WHERE PickDetailKey = @c_PickDetailKey 
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78311
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END          
                                                                                                                    
               END -- ELSE @n_PickLocAvailableQty >= @n_PickQty        
                                        
               SET @n_ReplenQty = @n_ReplenQty - @n_PickQty

               IF @b_Debug = 1
               BEGIN
                  PRINT '  >>  @n_ReplenQty: ' +  CAST(@n_ReplenQty AS VARCHAR(10))   
               END                  
            END -- IF @n_ReplenQty > 0
            IF @n_ReplenQty = 0 AND @n_FullCasePickQty = 0
               BREAK             
               
            FETCH NEXT FROM CUR_PICKDETAIL_RECORDS INTO @c_PickDetailKey, @n_PickQty, @b_ExistsFlag, @n_PT_RowRef  
         END -- While CUR_PICKDETAIL_RECORDS Loop 
         CLOSE CUR_PICKDETAIL_RECORDS
         DEALLOCATE CUR_PICKDETAIL_RECORDS   

         IF @b_Debug = 1
         BEGIN
            PRINT '      ReplenQty:' + CAST(@n_ReplenQty AS VARCHAR(10)) + 
                  ', QtyTakeFromPickLoc:' + CAST(@n_QtyTakeFromPickLoc AS VARCHAR(10)) + 
                  ', QtyAvaliable:' + CAST(@n_QtyAvaliable AS VARCHAR(10)) +
                  ', LooseQtyFromBulk:' + CAST(@n_LooseQtyFromBulk AS VARCHAR(10))
         END 
                           
         --IF (@n_ReplenQty + @n_QtyTakeFromPickLoc > 0) AND @n_QtyAvaliable > 0 AND @n_LooseQtyFromBulk > @n_QtyTakeFromPickLoc
         --BEGIN
            --UPDATE REPLENISHMENT WITH (ROWLOCK) 
            --SET Qty = Qty + @n_ReplenQty + @n_QtyTakeFromPickLoc,
            --    QtyReplen = QtyReplen + @n_ReplenQty + @n_QtyTakeFromPickLoc,
            --    PendingMoveIn = PendingMoveIn + @n_ReplenQty + @n_QtyTakeFromPickLoc,  
            --    EditDate = GETDATE(),
            --    EditWho = SUSER_SNAME()
            --WHERE ReplenishmentKey = @c_ReplenishmentKey   
            --IF @@ERROR <> 0 
            --BEGIN
            --   SELECT @n_continue = 3
            --   SELECT @n_err = 78300
            --   SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update Replenishment Failed! (ispGenEOrderReplen03)'
            --   GOTO EXIT_SP       
            --END     
                              
         --   IF @b_Debug = 1
         --   BEGIN
         --      PRINT '  >>  Remaining Replen Key: ' +  @c_ReplenishmentKey + ', Replen Qty:' + CAST(@n_ReplenQty AS VARCHAR(10))              
         --   END          
         --END
               
      END -- IF @c_ToLOC <> ''
      ELSE 
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '  >>  No Pick or Dynamic Pick Location Setup '                
         END
      END

      COMMIT TRAN

      FETCH NEXT FROM CUR_Bulk_Replenishment INTO 
            @c_StorerKey, @c_Facility, @c_SKU, @c_LOC, @c_LOT, @c_ID, @n_QtyOrdered, @n_CaseCnt, @c_PackKey, @c_UOM      
   END
   CLOSE CUR_Bulk_Replenishment
   DEALLOCATE CUR_Bulk_Replenishment
   
   ----------- ****************************************** ----------------
   IF @b_Debug = 1
   BEGIN
      PRINT ''
      PRINT '------------------------------------------------------------'
      PRINT '>>>   Find Available Qty or Swap with other PickDetail   <<<'
      PRINT '------------------------------------------------------------' 
   END 

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   BEGIN TRAN
                     
   SET @c_PickDetailKey = ''

   WHILE 1=1 
   BEGIN
      SELECT  TOP 1 
              @c_PickDetailKey = p.PickDetailKey, 
              @n_QtyAllocPick  = p.Qty, 
              @c_LOT           = p.Lot, 
              @c_LOC           = p.loc, 
              @c_ID            = p.ID, 
              @c_UOM           = p.UOM, 
              @c_Facility      = L.Facility, 
              @c_StorerKey     = p.Storerkey, 
              @c_SKU           = p.Sku,
              @c_DoReplenish   = P.DoReplenish 
      FROM PICKDETAIL AS p WITH (NOLOCK)  
      JOIN Orderdetail as OD (NOLOCK) on OD.orderkey = p.orderkey and od.orderlinenumber = p.orderlinenumber          
      JOIN SKUxLOC AS  SL WITH (NOLOCK) 
               ON SL.Storerkey = P.Storerkey 
              AND SL.Sku = P.Sku   
              AND SL.Loc = P.Loc 
      JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc           
      WHERE P.[Status] = '0'
      AND   SL.LocationType IN ('PICK', 'CASE')
      AND   P.UOM IN ('7','6')   
      AND   P.DoReplenish = 'N'
      AND   P.PickDetailKey > @c_PickDetailKey      
      AND   l.LocationType = 'PICK' --CONV
      AND   l.LocationCategory = 'OTHER'  --CONV
      AND   l.Hostwhcode = 'SA'  --CONV      
      AND EXISTS ( SELECT 1 FROM @tTaskOrders AS PT WHERE PT.OrderKey = OD.OrderKey  ) 
      ORDER BY P.PickDetailKey
      IF @@ROWCOUNT = 0 
         BREAK 
      
      BEGIN TRAN
            
      IF @c_UOM = '6'
      BEGIN
         UPDATE PickDetail WITH (ROWLOCK) 
            SET DoReplenish = 'Y', TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(), ReplenishZone = 'DoReplen'
         WHERE PickDetailKey = @c_PickDetailKey 
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78311
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
            GOTO EXIT_SP         
         END      
                              
         GOTO FETCH_NEXT_PICKDET
      END
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>   PickDetailKey:' + CAST(@c_PickDetailKey AS VARCHAR(10)) + 
               ', Pick Det Qty:' + CAST(@n_QtyAllocPick AS VARCHAR(10))
         PRINT '      SKU: ' + @c_SKU   
         PRINT '      LOT: ' + @c_LOT 
      END 
               
      WHILE @n_QtyAllocPick > 0 
      BEGIN
         SET @n_QtyAvaliable = 0 
         SET @c_FromLOT = ''
         SET @c_FromLOC = ''
         SET @c_FromID  = ''
         
         --find same lot,loc,id
         SELECT TOP 1 
                @n_QtyAvaliable = lli.Qty - lli.QtyAllocated - lli.QtyPicked, 
                @c_FromLOT = lli.Lot,
                @c_FromLOC = lli.Loc, 
                @c_FromID  = lli.ID   
         FROM LOTxLOCxID AS lli WITH(NOLOCK) 
         WHERE lli.Lot = @c_LOT
         AND lli.Loc = @c_LOC
         AND lli.Id = @c_ID
         AND lli.Qty - (lli.QtyAllocated + lli.QtyPicked) >= @n_QtyAllocPick 
         
         IF @n_QtyAvaliable = 0 
         BEGIN
         	  --find same lot,loc and diffrent id
            SELECT TOP 1 
                @n_QtyAvaliable = lli.Qty - lli.QtyAllocated - lli.QtyPicked, 
                @c_FromLOT = lli.Lot,
                @c_FromLOC = lli.Loc, 
                @c_FromID  = lli.ID   
            FROM LOTxLOCxID AS lli WITH(NOLOCK) 
            WHERE lli.Lot = @c_LOT
            AND lli.Loc = @c_LOC
            AND lli.Qty - (lli.QtyAllocated + lli.QtyPicked) >= @n_QtyAllocPick
            ORDER BY (lli.Qty - lli.QtyAllocated - lli.QtyPicked) DESC 
            
         END
         
         IF @n_QtyAvaliable = 0 
         BEGIN
         	  --find same loc diffent lot,id with lottable matching
            IF @c_ForceAllocLottable = '1'
            BEGIN
               SELECT
                  @c_Lottable01 = Lottable01,
                  @c_Lottable02 = Lottable02,
                  @c_Lottable03 = Lottable03,
                  @c_Lottable06 = Lottable06,
                  @c_Lottable07 = Lottable07,
                  @c_Lottable08 = Lottable08,
                  @c_Lottable09 = Lottable09,
                  @c_Lottable10 = Lottable10,
                  @c_Lottable11 = Lottable11,
                  @c_Lottable12 = Lottable12             
               FROM LOTATTRIBUTE LA WITH (NOLOCK) 
               WHERE LOT = @c_LOT               
                
               SELECT @c_SQLSelect =
                 N'SELECT TOP 1 ' + 
                 '  @n_QtyAvaliable =  lli.Qty - lli.QtyAllocated - lli.QtyPicked, ' + 
                 '  @c_FromLOT = lli.Lot, ' + 
                 '  @c_FromLOC = lli.Loc, ' + 
                 '  @c_FromID  = lli.ID   ' + 
                 ' FROM LOTxLOCxID AS lli WITH(NOLOCK) ' + 
                 ' JOIN  LOTATTRIBUTE AS LA WITH (NOLOCK) ON LA.LOT = lli.LOT ' + 
                 ' JOIN LOC L WITH (NOLOCK) ON L.Loc = lli.Loc ' + 
                 ' WHERE lli.StorerKey = @c_StorerKey ' + 
                 ' AND   lli.Sku = @c_SKU   ' + 
                 ' AND lli.Loc = @c_LOC ' + 
                 ' AND lli.Qty - (lli.QtyAllocated + lli.QtyPicked) > 0  ' +
               CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable01 = @c_Lottable01 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable02 = @c_Lottable02 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable03 = @c_Lottable03 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable06 = @c_Lottable06 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable07 = @c_Lottable07 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable08 = @c_Lottable08 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable09 = @c_Lottable09 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable10 = @c_Lottable10 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable11 = @c_Lottable11 ' END +
               CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable12 = @c_Lottable12 ' END
               
               EXEC sp_executesql @c_SQLSelect, 
                  N'@c_StorerKey  NVARCHAR(15)
                  , @c_LOC        NVARCHAR(10)
                  , @c_SKU        NVARCHAR(20) 
                  , @c_FromLOT    NVARCHAR(10) OUTPUT
                  , @c_FromLOC    NVARCHAR(10) OUTPUT
                  , @c_FromID     NVARCHAR(18) OUTPUT  
                  , @n_QtyAvaliable INT        OUTPUT
                  , @c_Lottable01 NVARCHAR(18)
                  , @c_Lottable02 NVARCHAR(18)
                  , @c_Lottable03 NVARCHAR(18)
                  , @d_Lottable04 DATETIME
                  , @c_Lottable06 NVARCHAR(30)
                  , @c_Lottable07 NVARCHAR(30)
                  , @c_Lottable08 NVARCHAR(30)
                  , @c_Lottable09 NVARCHAR(30)
                  , @c_Lottable10 NVARCHAR(30)
                  , @c_Lottable11 NVARCHAR(30)
                  , @c_Lottable12 NVARCHAR(30)'  
                  , @c_StorerKey  
                  , @c_LOC        
                  , @c_SKU        
                  , @c_FromLOT      OUTPUT
                  , @c_FromLOC      OUTPUT
                  , @c_FromID       OUTPUT 
                  , @n_QtyAvaliable OUTPUT
                  , @c_Lottable01 
                  , @c_Lottable02 
                  , @c_Lottable03 
                  , @d_Lottable04 
                  , @c_Lottable06 
                  , @c_Lottable07 
                  , @c_Lottable08 
                  , @c_Lottable09 
                  , @c_Lottable10 
                  , @c_Lottable11 
                  , @c_Lottable12      
            END -- @c_ForceAllocLottable = '1'
            ELSE 
            BEGIN
            	 --find same loc any available lot,id
               SELECT TOP 1 
                   @n_QtyAvaliable =  lli.Qty - lli.QtyAllocated - lli.QtyPicked, 
                   @c_FromLOT = lli.Lot,
                   @c_FromLOC = lli.Loc, 
                   @c_FromID  = lli.ID   
               FROM LOTxLOCxID AS lli WITH(NOLOCK) 
               JOIN LOC L WITH (NOLOCK) ON L.Loc = lli.Loc 
               WHERE lli.StorerKey = @c_StorerKey 
               AND   lli.Sku = @c_SKU   
               AND lli.Loc = @c_LOC 
               AND L.Facility = @c_Facility 
               AND lli.Qty - (lli.QtyAllocated + lli.QtyPicked) > 0              
            END

         END         
         
         IF @n_QtyAvaliable > 0 
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT '  *** Found Available Qty ***'
               PRINT '      QtyAvaliable:' + CAST(@n_QtyAvaliable AS VARCHAR(10))  
               PRINT '      From LOT:' + @c_FromLOT + ', ID:' + @c_FromID
            END 
            
            --sufficeint stock      
            IF @n_QtyAvaliable >= @n_QtyAllocPick           
            BEGIN
            	 --same lot, loc, id
               IF @c_FromLOT = @c_LOT AND @c_FromLOC = @c_LOC AND @c_FromID = @c_ID 
               BEGIN
                  UPDATE PickDetail WITH (ROWLOCK) 
                     SET UOM = '6', DoReplenish = 'Y', TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(), ReplenishZone = 'QtyAvlbl'   --change to uom 6 (no replen)
                  WHERE PickDetailKey = @c_PickDetailKey 
               END
               ELSE   
               BEGIN
                  UPDATE PickDetail WITH (ROWLOCK) 
                     SET UOM = '6', DoReplenish = 'Y', 
                         LOT = @c_FromLOT,
                         LOC = @c_FromLOC,
                         ID = @c_ID, 
                         EditDate = GETDATE(), 
                         EditWho = SUSER_SNAME(),
                         ReplenishZone = 'SwapLot', 
                         CartonType = LOT                       
                         --ToLoc = LOT 
                   WHERE PickDetailKey = @c_PickDetailKey      
               END
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78312
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                  GOTO EXIT_SP         
               END 
                        
               SET @n_QtyAllocPick = 0 
            END -- IF @n_QtyAvaliable >= @n_QtyAllocPick
            ELSE 
            BEGIN -- Split PickDetail 
               SET @c_NewPickDetailKey = ''
                                    
               EXECUTE dbo.nspg_GetKey  
                  'PICKDETAILKEY',   
                  10 ,  
                  @c_NewPickDetailKey  OUTPUT,  
                  @b_success        OUTPUT,  
                  @n_err            OUTPUT,  
                  @c_errmsg         OUTPUT  
     
               IF @b_success <> 1  
               BEGIN  
                  SET @n_Err = 63885  
                  SET @c_ErrMsg = 'Get Pickdetail Key'
                  SET @n_Continue = 3
                  GOTO EXIT_SP
               END 

               IF @b_Debug = 1
               BEGIN
                  PRINT '  *** Split PickDetail ***'
                  PRINT '      New PickDetailKey: ' + @c_NewPickDetailKey + ', Qty: ' 
                        + CAST((@n_QtyAllocPick - @n_QtyAvaliable) AS VARCHAR(10))  
               END
               
               --NJOW01 move up to before insert new split pickdetail and calculate splitQty
               SET @n_SplitQty = 0
               SELECT @n_SplitQty = Qty - @n_QtyAvaliable
               FROM PICKDETAIL (NOLOCK) 
               WHERE Pickdetailkey = @c_PickDetailKey 
               
               UPDATE PickDetail WITH (ROWLOCK)
                  SET UOM = '6', DoReplenish = 'Y', 
                        LOT = @c_FromLOT,
                        LOC = @c_FromLOC,
                        ID = @c_ID, 
                        Qty = @n_QtyAvaliable, 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME(),
                        ReplenishZone='SwapLot2',
                        CartonType = LOT                        
                        --ToLoc = LOT 
 
                   WHERE PickDetailKey = @c_PickDetailKey
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78315
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                  GOTO EXIT_SP         
               END 
                
               ---NJOW01 change optimizecop to NULL. select from @c_Lot,@c_Loc, @c_DoReplenish, @c_UOM, @n_splitQty
               INSERT INTO dbo.PICKDETAIL
                  (
                   PickDetailKey    ,CaseID           ,PickHeaderKey
                  ,OrderKey         ,OrderLineNumber  ,Lot
                  ,Storerkey        ,Sku              ,AltSku
                  ,UOM              ,UOMQty           ,Qty
                  ,QtyMoved         ,STATUS           ,DropID
                  ,Loc              ,ID               ,PackKey
                  ,UpdateSource     ,CartonGroup      ,CartonType
                  ,ToLoc            ,DoReplenish      ,ReplenishZone
                  ,DoCartonize      ,PickMethod       ,WaveKey
                  ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                  ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                  ,Channel_ID   
                  )
               SELECT @c_NewPickDetailKey  AS PickDetailKey
                     ,CaseID           ,PickHeaderKey    ,OrderKey
                     ,OrderLineNumber  ,@c_Lot           ,Storerkey
                     ,Sku              ,AltSku           ,@c_UOM
                     ,UOMQty           
                     --,Qty - @n_QtyAvaliable -- (SWT02) --,@n_QtyAllocPick - @n_QtyAvaliable
                     ,@n_SplitQty
                     ,QtyMoved         ,[STATUS]         ,DropID       
                     ,@c_Loc           ,ID               ,PackKey      
                     ,UpdateSource     ,CartonGroup      ,CartonType      
                     ,@c_PickDetailKey ,@c_DoReplenish   ,ReplenishZone='SplitPD'      
                     ,DoCartonize      ,PickMethod       ,WaveKey      
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop      
                     ,NULL             ,ShipFlag         ,PickSlipNo  
                     ,Channel_ID  
               FROM   dbo.PickDetail WITH (NOLOCK)
               WHERE  PickDetailKey = @c_PickDetailKey -- Fix (SWT01)
               --WHERE  PickDetailKey = @c_SwapPickDetailKey 
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 78313
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispGenEOrderReplen03)'
                  GOTO EXIT_SP         
               END                   
                                 
               SET @n_QtyAllocPick = @n_QtyAllocPick - @n_QtyAvaliable                                
            END
         END -- IF @n_QtyAvaliable > 0 
         ELSE 
         BEGIN -- IF @n_QtyAvaliable = 0 
            SET @c_SwapPickDetailKey = ''
            SET @n_SwapQty = 0 
            
            -- swap with other batch of pick not release batch yet
            SELECT TOP 1 
               @c_SwapPickDetailKey = P.PickDetailKey, 
               @c_FromLOT = P.Lot,
               @c_FromLOC = P.Loc, 
               @c_FromID  = P.ID, 
               @n_SwapQty = P.Qty               
            FROM  PICKDETAIL P WITH (NOLOCK) 
            JOIN  ORDERS AS o WITH(NOLOCK) ON o.OrderKey = P.OrderKey AND o.DocType = 'E'
            WHERE NOT EXISTS ( SELECT 1 FROM @tTaskOrders AS PT WHERE PT.OrderKey = P.OrderKey  ) 
            AND   P.DoReplenish = 'N'
            AND   P.LOC = @c_LOC
            AND   P.UOM = '6'
            AND   P.Storerkey = @c_StorerKey
            AND   P.Sku = @c_SKU 
            AND   P.STATUS < '4'    
            AND   P.ShipFlag NOT IN ('P','Y') 
            ORDER BY CASE WHEN P.lot = @c_LOT AND P.ID = @c_ID THEN 1 
                          WHEN P.lot = @c_LOT THEN 2
                          ELSE 3 
                     END, 
                     CASE WHEN P.Qty = @n_QtyAllocPick THEN 1 
                          WHEN P.Qty > @n_QtyAllocPick THEN 2 
                          ELSE 3 
                     END, 
                     P.PickDetailKey
            
            IF @c_SwapPickDetailKey <> '' 
            BEGIN
               IF @n_SwapQty > @n_QtyAllocPick
               BEGIN
                  SET @c_NewPickDetailKey = ''
                                    
                  EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',   
                     10 ,  
                     @c_NewPickDetailKey  OUTPUT,  
                     @b_success        OUTPUT,  
                     @n_err            OUTPUT,  
                     @c_errmsg         OUTPUT  
     
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_Err = 63885  
                     SET @c_ErrMsg = 'Get Pickdetail Key'
                     SEt @n_Continue = 3
                     GOTO EXIT_SP
                  END 

                  IF @b_Debug = 1
                  BEGIN
                     PRINT '  *** Split PickDetail ***'
                     PRINT '      New PickDetailKey: ' + @c_NewPickDetailKey + ', Qty: ' 
                           + CAST((@n_SwapQty - @n_QtyAllocPick) AS VARCHAR(10))  
                  END
                  
                  INSERT INTO dbo.PICKDETAIL
                    (
                      PickDetailKey    ,CaseID           ,PickHeaderKey
                     ,OrderKey         ,OrderLineNumber  ,Lot
                     ,Storerkey        ,Sku              ,AltSku
                     ,UOM              ,UOMQty           ,Qty
                     ,QtyMoved         ,STATUS           ,DropID
                     ,Loc              ,ID               ,PackKey
                     ,UpdateSource     ,CartonGroup      ,CartonType
                     ,ToLoc            ,DoReplenish      ,ReplenishZone
                     ,DoCartonize      ,PickMethod       ,WaveKey
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                     ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                     ,Channel_ID   --WL01
                    )
                  SELECT @c_NewPickDetailKey  AS PickDetailKey
                        ,CaseID           ,PickHeaderKey    ,OrderKey
                        ,OrderLineNumber  ,Lot              ,Storerkey
                        ,Sku              ,AltSku           ,UOM
                        ,UOMQty           ,Qty - @n_QtyAllocPick
                        ,QtyMoved         ,[STATUS]         ,DropID       
                        ,Loc              ,ID               ,PackKey      
                        ,UpdateSource     ,CartonGroup      ,CartonType      
                        ,@c_SwapPickDetailKey ,DoReplenish  ,ReplenishZone='SplitPD2_A'      
                        ,DoCartonize      ,PickMethod       ,WaveKey      
                        ,EffectiveDate    ,TrafficCop       ,ArchiveCop      
                        ,'1'              ,ShipFlag         ,PickSlipNo
                        ,Channel_ID   --WL01
                  FROM   dbo.PickDetail WITH (NOLOCK)
                  WHERE  PickDetailKey = @c_SwapPickDetailKey 
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78316
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END 
                           
                  UPDATE PickDetail WITH (ROWLOCK)
                     SET Qty = @n_QtyAllocPick, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(), ReplenishZone='SplitPD2_B'
                  WHERE PickDetailKey = @c_SwapPickDetailKey
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78317
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END 
                           
                  SET @n_SwapQty =  @n_QtyAllocPick   
                                       
               END  -- @n_SwapQty > @n_QtyAllocPick
               ELSE 
               IF @n_QtyAllocPick > @n_SwapQty 
               BEGIN
                  SET @c_NewPickDetailKey = ''
                                    
                  EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',   
                     10 ,  
                     @c_NewPickDetailKey  OUTPUT,  
                     @b_success        OUTPUT,  
                     @n_err            OUTPUT,  
                     @c_errmsg         OUTPUT  
     
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_Err = 63885  
                     SET @c_ErrMsg = 'Get Pickdetail Key'
                     SEt @n_Continue = 3
                     GOTO EXIT_SP
                  END 

                  IF @b_Debug = 1
                  BEGIN
                     PRINT '  *** Split PickDetail ***'
                     PRINT '      New PickDetailKey: ' + @c_NewPickDetailKey + ', Qty: ' 
                           + CAST((@n_SwapQty - @n_QtyAllocPick) AS VARCHAR(10))  
                  END
                  
                  INSERT INTO dbo.PICKDETAIL
                    (
                      PickDetailKey    ,CaseID           ,PickHeaderKey
                     ,OrderKey         ,OrderLineNumber  ,Lot
                     ,Storerkey        ,Sku              ,AltSku
                     ,UOM              ,UOMQty           ,Qty
                     ,QtyMoved         ,STATUS           ,DropID
                     ,Loc              ,ID               ,PackKey
                     ,UpdateSource     ,CartonGroup      ,CartonType
                     ,ToLoc            ,DoReplenish      ,ReplenishZone
                     ,DoCartonize      ,PickMethod       ,WaveKey
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                     ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                     ,Channel_ID   --WL01
                    )
                  SELECT @c_NewPickDetailKey  AS PickDetailKey
                        ,CaseID           ,PickHeaderKey    ,OrderKey
                        ,OrderLineNumber  ,Lot              ,Storerkey
                        ,Sku              ,AltSku           ,UOM
                        ,UOMQty           ,Qty - @n_SwapQty  
                        ,QtyMoved         ,[STATUS]         ,DropID       
                        ,Loc              ,ID               ,PackKey      
                        ,UpdateSource     ,CartonGroup      ,CartonType      
                        ,@c_PickDetailKey ,DoReplenish      ,ReplenishZone='SplitPD3_A'      
                        ,DoCartonize      ,PickMethod       ,WaveKey      
                        ,EffectiveDate    ,TrafficCop       ,ArchiveCop      
                        ,'1'              ,ShipFlag         ,PickSlipNo
                        ,Channel_ID   --WL01
                  FROM   dbo.PickDetail WITH (NOLOCK)
                  WHERE  PickDetailKey = @c_PickDetailKey 
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78319
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END 
                           
                  UPDATE PickDetail WITH (ROWLOCK)
                     SET Qty = @n_SwapQty, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(),ReplenishZone='SplitPD3_B'
                  WHERE PickDetailKey = @c_PickDetailKey
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78320
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END                   
                  SET @n_QtyAllocPick = @n_SwapQty                      
               END -- @n_QtyAllocPick > @n_SwapQty
               ELSE IF @n_QtyAllocPick = @n_SwapQty -- (SWT02) 
               BEGIN
                  IF @c_FromLOT = @c_LOT AND 
                     @c_FromLOC = @c_LOC AND 
                     @c_FromID = @c_ID  
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        PRINT '  *** Exchange UOM ***'
                        PRINT '      With PickDetailKey: ' + @c_SwapPickDetailKey 
                     END
                                    
                     UPDATE PICKDETAIL WITH (ROWLOCK) 
                        SET UOM = '7', TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(), ReplenishZone='ExchUOM6'
                     WHERE PickDetailKey = @c_SwapPickDetailKey
                     IF @@ERROR <> 0 
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 78321
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                        GOTO EXIT_SP         
                     END 
                        
                     UPDATE PICKDETAIL WITH (ROWLOCK) 
                        SET UOM = '6', DoReplenish = 'Y', TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME(), ReplenishZone='ExchUOM7'
                     WHERE PickDetailKey = @c_PickDetailKey             
                     IF @@ERROR <> 0 
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 78322
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                        GOTO EXIT_SP         
                     END               
                  END -- same lot, loc, id
                  ELSE 
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        PRINT '  *** Swap Lot ***'
                        PRINT '      With LOT:' + @c_FromLOT
                        PRINT '      With PickDetailKey: ' + @c_SwapPickDetailKey 
                     END 
                                 
                     UPDATE PICKDETAIL WITH (ROWLOCK) 
                        SET UOM = '7',
                            LOT = @c_LOT, 
                            LOC = @c_LOC, 
                            ID  = @c_ID,  
                            TrafficCop = NULL, 
                            EditDate = GETDATE(), 
                            EditWho = SUSER_SNAME(),
                            ReplenishZone='SwapLot3',
                            CartonType = LOT                       
                            --ToLoc = LOT 
                     WHERE PickDetailKey = @c_SwapPickDetailKey
                     IF @@ERROR <> 0 
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 78323
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                        GOTO EXIT_SP         
                     END 
                        
                     UPDATE PICKDETAIL WITH (ROWLOCK) 
                        SET UOM = '6',
                              LOT = @c_FromLOT, 
                              LOC = @c_FromLOC, 
                              ID  = @c_FromID,                     
                              DoReplenish = 'Y', 
                              TrafficCop = NULL, 
                              EditDate = GETDATE(), 
                              EditWho = SUSER_SNAME(),
                              ReplenishZone='SwapLot4',
                              CartonType = LOT                        
                             --ToLoc = LOT 
                     WHERE PickDetailKey = @c_PickDetailKey  
                     IF @@ERROR <> 0 
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 78324
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
                        GOTO EXIT_SP         
                     END                                             
                  END     
                                                
               END -- @n_QtyAllocPick = @n_SwapQty
               SET @n_QtyAllocPick = @n_QtyAllocPick - @n_SwapQty                         
            END
            ELSE IF @c_SwapPickDetailKey = ''
            BEGIN
               BREAK
            END                
         END -- -- IF @n_QtyAvaliable = 0
         
         IF @n_QtyAllocPick = 0 
            BREAK
      END
            
      FETCH_NEXT_PICKDET:
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN
         BEGIN TRAN
      END
   END -- WHILE LOOP
   
   BEGIN TRAN

   ----------- ****************************************** ----------------
   -- Generate Replenishment for OverAllocated PickDetail.
   IF @b_Debug = 1
   BEGIN
      PRINT ''
      PRINT '---------------------------------------------------------------'
      PRINT '>>>   Generate Replenishment for OverAllocated PickDetail   <<<'
      PRINT '---------------------------------------------------------------' 
   END 
      
   DECLARE @n_PendingMoveIn INT = 0 
   DECLARE @n_QtyInPickLoc  INT = 0 
   DECLARE @t_AllocatedLOT TABLE (LOT NVARCHAR(10))
   
   DECLARE CUR_OVERALLOCATE_LOC CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT L.Facility, P.Storerkey, P.Sku, P.Loc, 
          SUM(P.Qty) AS QtyExpected, 
          SL.QtyLocationLimit  
   FROM PICKDETAIL AS p WITH (NOLOCK)                  
   JOIN SKUxLOC AS  SL WITH (NOLOCK) 
            ON SL.Storerkey = P.Storerkey 
           AND SL.Sku = P.Sku   
           AND SL.Loc = P.Loc 
   JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc 
   JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey  
   WHERE P.[Status] = '0'
   AND   SL.LocationType IN ('PICK', 'CASE')
   AND   P.UOM = '7'     
   AND   P.DoReplenish = 'N'
   AND   l.LocationType = 'PICK' --CONV
   AND   l.LocationCategory = 'OTHER'  --CONV
   AND   l.Hostwhcode = 'SA'  --CONV         
   
   GROUP BY L.Facility, P.Storerkey, P.Sku, P.Loc, SL.QtyPicked, SL.Qty, SL.QtyLocationLimit
                         
   OPEN CUR_OVERALLOCATE_LOC
   
   FETCH NEXT FROM CUR_OVERALLOCATE_LOC INTO @c_Facility, @c_StorerKey ,@c_SKU, @c_LOC, @n_ReplenQty, @n_LocCapacity
   WHILE @@FETCH_STATUS = 0 
   BEGIN    
      
      SELECT @n_PendingMoveIn = SUM(ISNULL(LLI.PendingMoveIN,0))   
      FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
      WHERE LLI.StorerKey = @c_StorerKey 
      AND   LLI.Sku = @c_SKU 
      AND   LLI.Loc = @c_LOC      
      
      SELECT @n_CaseCnt = P.CaseCnt, 
             @c_UOM  = P.PackUOM3, 
             @c_PackKey = SKU.PACKKey
      FROM SKU WITH (NOLOCK) 
      JOIN PACK AS p WITH(NOLOCK) ON P.PACKKey = SKU.PACKKey 
      WHERE StorerKey = @c_StorerKey
      AND   SKU = @c_SKU 
      
      IF @b_Debug=1
      BEGIN
         PRINT '>>>   SKU:' + @c_SKU + ', Loc:' + @c_LOC +  ', LocCapacity: ' + CAST(@n_LocCapacity AS VARCHAR(10))
         PRINT '      Replen Qty: ' + CAST(@n_ReplenQty AS VARCHAR(10))
         PRINT '      Pending MoveIn Qty: ' + CAST(@n_PendingMoveIn AS VARCHAR(10))
      END      
      
      -- If Pending Move In Qty more than Qty Replen, Do nothing
      IF @n_ReplenQty <= @n_PendingMoveIn
      BEGIN
         GOTO FETCH_NEXT
      END
               
      SET @n_ReplenQty = @n_ReplenQty - @n_PendingMoveIn
      
      SET @n_QtyInPickLoc = @n_ReplenQty  
      WHILE @n_ReplenQty > 0 
      BEGIN          
         DELETE @t_AllocatedLOT  
         
         INSERT INTO @t_AllocatedLOT (LOT)
         SELECT DISTINCT p.LOT 
         FROM PICKDETAIL AS p WITH (NOLOCK)                  
         JOIN SKUxLOC AS  SL WITH (NOLOCK) 
                  ON SL.Storerkey = P.Storerkey 
                  AND SL.Sku = P.Sku   
                  AND SL.Loc = P.Loc 
         JOIN LOC AS l WITH(NOLOCK) ON l.Loc = SL.Loc  
         JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey          
         WHERE P.[Status] = '0'
         AND   SL.LocationType IN ('PICK', 'CASE')
         AND   P.UOM = '7'  
         AND   P.DoReplenish = 'N'
         AND   P.StorerKey = @c_StorerKey 
         AND   P.SKU = @c_SKU
         AND   P.LOC = @c_LOC  
                 
         IF @c_EOrderReplenByUCC = '1'  
         BEGIN
            SET @c_FromLOC = ''
            SET @c_FromID  = ''
            SET @c_FromLOT = ''
            SET @n_UCCQty = 0          	
            SET @c_UCCNo = ''

            SELECT TOP 1  
               @c_FromLOC = LLI.LOC, 
               @c_FromID  = LLI.ID, 
               @n_UCCQty = UCC.Qty, 
               @c_FromLOT = LLI.LOT,
               @c_UCCNo = UCC.UCCNo
            FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
            JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
            JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
            JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
            JOIN ID (NOLOCK) ON (LLI.ID = ID.ID) 
            JOIN @t_AllocatedLOT AL ON AL.LOT = LLI.Lot 
            JOIN UCC WITH (NOLOCK) ON UCC.StorerKey = LLI.StorerKey AND UCC.SKU = LLI.SKU AND 
                                      UCC.LOT = LLI.LOT AND UCC.LOC = LLI.LOC AND UCC.ID = LLI.ID AND UCC.Status < '3'
            WHERE LOT.STATUS = 'OK' 
            AND L.STATUS = 'OK' 
            AND ID.STATUS = 'OK' 
            AND L.LocationFlag = 'NONE' 
            AND L.LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK', 'FASTPICK') 
            AND (SL.LocationType NOT IN ('PICK','CASE') ) 
            AND L.Facility = @c_Facility
            AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) > 0
            AND L.LocationType = 'OTHER' --CONV
            AND L.LocationCategory = 'BULK'  --CONV
            AND L.Hostwhcode = 'SA'  --CONV                  
            ORDER BY L.LocationHandling, LLI.Qty, UCC.Qty, UCC.UCCNo
            
            IF ISNULL(@c_FromLoc,'') = ''
            BEGIN
               SELECT TOP 1  
                  @c_FromLOC = LLI.LOC, 
                  @c_FromID  = LLI.ID, 
                  @n_UCCQty = UCC.Qty, 
                  @c_FromLOT = LLI.LOT, 
                  @c_UCCNo = UCC.UCCNo
               FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
               JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
               JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
               JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
               JOIN ID (NOLOCK) ON (LLI.ID = ID.ID)
               JOIN UCC WITH (NOLOCK) ON UCC.StorerKey = LLI.StorerKey AND UCC.SKU = LLI.SKU AND 
                                         UCC.LOT = LLI.LOT AND UCC.LOC = LLI.LOC AND UCC.ID = LLI.ID AND UCC.Status < '3'
               WHERE LOT.STATUS = 'OK' 
               AND L.STATUS = 'OK' 
               AND ID.STATUS = 'OK' 
               AND L.LocationFlag = 'NONE' 
               AND L.LocationType NOT IN ('PICK') 
               AND (SL.LocationType NOT IN ('PICK','CASE') ) 
               AND L.Facility = @c_Facility
               AND LLI.StorerKey = @c_StorerKey 
               AND LLI.Sku = @c_SKU
               AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) > 0                
               AND L.LocationType = 'OTHER' --CONV
               AND L.LocationCategory = 'BULK'  --CONV
               AND L.Hostwhcode = 'SA'  --CONV                                 
               ORDER BY L.LocationHandling, LLI.Qty, UCC.Qty, UCC.UCCNo             	
            END

            IF @c_FromLOC <> '' AND @c_FromLOT <> '' AND @n_UCCQty > 0 
            BEGIN
               SET @n_QtyToTake = @n_UCCQty 
               
               IF @n_QtyToTake > 0 
               BEGIN
                  EXECUTE nspg_GetKey
                     'REPLENISHKEY'
                  ,  10
                  ,  @c_ReplenishmentKey  OUTPUT
                  ,  @b_Success           OUTPUT 
                  ,  @n_Err               OUTPUT 
                  ,  @c_ErrMsg            OUTPUT
                  
                  IF @b_Success <> 1 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78325
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END
                  
                  SET @c_MoveRefKey = 'ECOM' --WWANG02

                  IF @n_ReplenQty > @n_QtyToTake
                     SET @n_QtyInPickLoc = @n_QtyToTake
                  ELSE 
                     SET @n_QtyInPickLoc = @n_ReplenQty          
                                                                                                   
                  INSERT INTO REPLENISHMENT(
                        Replenishmentgroup, ReplenishmentKey, StorerKey,
                        Sku,                FromLoc,          ToLoc,
                        Lot,                Id,               Qty,
                        UOM,                PackKey,          Confirmed, 
                        MoveRefKey,         ToID,             PendingMoveIn, 
                        QtyReplen,          QtyInPickLoc,     RefNo )
                  VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                           @c_SKU,                @c_FromLOC,          @c_LOC, 
                           @c_FromLOT,            @c_FromID,           @n_QtyToTake, 
                           @c_UOM,                @c_PackKey,          'N', 
                           @c_MoveRefKey,         @c_ToID,             @n_QtyToTake, 
                           @n_QtyToTake,          @n_QtyInPickLoc,     @c_UCCNo )  
                           
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78326
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END                         
            
                  UPDATE UCC WITH (ROWLOCK)
                  SET Status = '5',
                      Userdefined10 = @c_ReplenishmentKey
                  WHERE UCCNo = @c_UCCNo
                  AND Status < '3'
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78315
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END                               
               END                                    
                        
               SET @n_ReplenQty = @n_ReplenQty - @n_QtyToTake                                         
            END --NJOW03 End
            ELSE
            BEGIN
               SET @n_ReplenQty = 0                
               BREAK
            END                        
         END
         ELSE                 
         BEGIN
            IF @b_Debug=1
            BEGIN
               PRINT '*     LOT: ' + @c_LOT  
            END
            -- Get available lot from Bulk 
            SET @c_FromLOC = ''
            SET @c_FromID  = ''
            SET @c_FromLOT = ''
            SET @n_QtyAvailable = 0 
            SET @cFastPickLoc = 'N'
            
            IF @b_Debug=1
            BEGIN
               PRINT '>>    Find inventory with same LOT, Qty Available >= Case Count'
            END
            
            SELECT TOP 1  
               @c_FromLOC = LLI.LOC, 
               @c_FromID  = LLI.ID, 
               @n_QtyAvailable = LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)), 
               @c_FromLOT = LLI.LOT 
            FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
            JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
            JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
            JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
            JOIN ID (NOLOCK) ON (LLI.ID = ID.ID) 
            JOIN @t_AllocatedLOT AL ON AL.LOT = LLI.Lot 
            WHERE LOT.STATUS = 'OK' 
            AND L.STATUS = 'OK' 
            AND ID.STATUS = 'OK' 
            AND L.LocationFlag = 'NONE' 
            AND L.LocationType NOT IN ('PICK') 
            AND (SL.LocationType NOT IN ('PICK','CASE') ) 
            AND L.Facility = @c_Facility
            AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) >= @n_CaseCnt  
            AND L.LocationType = 'OTHER' --CONV
            AND L.LocationCategory = 'BULK'  --CONV
            AND L.Hostwhcode = 'SA'  --CONV                              
            ORDER BY L.LocationHandling, LLI.Qty--, LOC.LocLevel, LOC.LocAisle 
            
            IF @c_FromLOC = ''
            BEGIN
               SET @cFastPickLoc = 'N'

               IF @b_Debug=1
               BEGIN
                  PRINT '>>    Find inventory with Other LOT, Qty Available >= Case Count'
               END
               
               SELECT TOP 1  
                  @c_FromLOC = LLI.LOC, 
                  @c_FromID  = LLI.ID, 
                  @n_QtyAvailable = LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)), 
                  @c_FromLOT = LLI.LOT 
               FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
               JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
               JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
               JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
               JOIN ID (NOLOCK) ON (LLI.ID = ID.ID)
               WHERE LOT.STATUS = 'OK' 
               AND L.STATUS = 'OK' 
               AND ID.STATUS = 'OK' 
               AND L.LocationFlag = 'NONE' 
               AND L.LocationType NOT IN ('PICK') 
               AND (SL.LocationType NOT IN ('PICK','CASE') ) 
               AND L.Facility = @c_Facility
               AND LLI.StorerKey = @c_StorerKey 
               AND LLI.Sku = @c_SKU
               AND LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)) >= @n_CaseCnt                
               AND L.LocationType = 'OTHER' --CONV
               AND L.LocationCategory = 'BULK'  --CONV
               AND L.Hostwhcode = 'SA'  --CONV                                 
               ORDER BY L.LocationHandling, LLI.Qty 
               
               -- If no full case qty available, get from fastpick location.
               IF @c_FromLOC = ''
               BEGIN
                  SET @cFastPickLoc = 'N'

                  IF @b_Debug=1
                  BEGIN
                     PRINT '>>    Find inventory with Any LOT in FASTPICK Location, Qty Available >= 0'
                  END
                                    
                  SELECT TOP 1  
                     @c_FromLOC = LLI.LOC, 
                     @c_FromID  = LLI.ID, 
                     @n_QtyAvailable = LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)), 
                     @c_FromLOT = LLI.LOT, 
                     @cFastPickLoc = 'Y' 
                  FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
                  JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
                  JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
                  JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
                  JOIN ID (NOLOCK) ON (LLI.ID = ID.ID)
                  WHERE LOT.STATUS = 'OK' 
                  AND L.STATUS = 'OK' 
                  AND ID.STATUS = 'OK' 
                  AND L.LocationFlag = 'NONE' 
                  AND L.LocationType IN ('FASTPICK') 
                  AND L.Facility = @c_Facility
                  AND LLI.StorerKey = @c_StorerKey 
                  AND LLI.Sku = @c_SKU                
                  AND LLI.Qty > (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0))               
                  ORDER BY L.LocationHandling, LLI.Qty  
                  
                  -- Added by Shong 6th Nov 2017, No full case found, take loose qty from Bulk 
                  IF @c_FromLOC = ''
                  BEGIN
                     
                     IF @b_Debug=1
                     BEGIN
                        PRINT '>>    Find inventory with Any LOT in BULK Location, Qty Available >= 0'
                     END
                                       
                     SELECT TOP 1  
                        @c_FromLOC = LLI.LOC, 
                        @c_FromID  = LLI.ID, 
                        @n_QtyAvailable = LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)), 
                        @c_FromLOT = LLI.LOT, 
                        @cFastPickLoc = 'Y' 
                     FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
                     JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
                     JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
                     JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
                     JOIN ID (NOLOCK) ON (LLI.ID = ID.ID)
                     WHERE LOT.STATUS = 'OK' 
                     AND L.STATUS = 'OK' 
                     AND ID.STATUS = 'OK' 
                     AND L.LocationFlag = 'NONE' 
                     AND SL.LocationType NOT IN ('PICK','CASE') 
                     AND L.Facility = @c_Facility
                     AND LLI.StorerKey = @c_StorerKey 
                     AND LLI.Sku = @c_SKU                
                     AND LLI.Qty > (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0))         
                     AND L.LocationType = 'OTHER' --CONV
                     AND L.LocationCategory = 'BULK'  --CONV
                     AND L.Hostwhcode = 'SA'  --CONV                                             
                     ORDER BY L.LocationHandling, LLI.Qty                     
                  END -- IF @c_FromLOC = '' Loose Carton             
               END  -- IF @c_FromLOC = '' (Non LOT - Full Case)            
            END -- IF @c_FromLOC = '' (LOT-Full Case)
            
            IF @c_FromLOC <> '' AND @c_FromLOT <> '' AND @n_QtyAvailable > 0 
            BEGIN
               SET @n_FullCasePickQty = 0 
               SET @n_QtyToTake = 0 
               
               IF @cFastPickLoc = 'N' AND @n_QtyAvailable >= @n_CaseCnt -- (SWT03)
               BEGIN
                  
                  SET @n_QtyAvailable = FLOOR( @n_QtyAvailable / @n_CaseCnt ) * @n_CaseCnt

                  SET @n_ReplenToMaxQty = ( FLOOR( (@n_ReplenQty + @n_LocCapacity) / @n_CaseCnt ) )
                                           * @n_CaseCnt 

                  SET @n_FullCasePickQty = ( FLOOR( @n_ReplenQty / @n_CaseCnt ) 
                                           + CASE WHEN  @n_ReplenQty % @n_CaseCnt > 0 THEN 1 ELSE 0 END )
                                           * @n_CaseCnt 
                                   
                  IF @n_ReplenToMaxQty > @n_FullCasePickQty
                     SET @n_FullCasePickQty = @n_ReplenToMaxQty
                  
                  SET @n_RemainingFullCase = 0                                                        
               END
               ELSE 
               BEGIN
                  SET @n_RemainingFullCase = @n_CaseCnt - @n_ReplenQty  
                                    
                  SET @n_FullCasePickQty = @n_ReplenQty
               END
                                                                                  
               IF @n_QtyAvailable >= @n_FullCasePickQty 
                  SET @n_QtyToTake = @n_FullCasePickQty
               ELSE 
                  SET @n_QtyToTake = @n_QtyAvailable  


               SET @c_MoveRefKey = 'ECOM'  
                
               -- If cannot find available Qty with full case, then find missing Qty taken by others
               IF (@cFastPickLoc = 'Y' AND @n_QtyAvailable < @n_CaseCnt)                           
               BEGIN     
               	SET @c_MoveRefKey = ''  
               	                               
                   DECLARE @n_QtyLocked INT, @n_QtyLockedToMove INT
                   SET @n_QtyToTake = @n_QtyAvailable                -- Take all available Qty if last carton is partial 
                   SET @n_QtyLocked = @n_CaseCnt - @n_QtyAvailable
                   SET @n_QtyLockedToMove = @n_QtyLocked
                   
                   EXECUTE nspg_GetKey  
                     'ReplMoveRef'  
                  ,  10  
                  ,  @c_MoveRefKey        OUTPUT  
                  ,  @b_Success           OUTPUT   
                  ,  @n_Err               OUTPUT   
                  ,  @c_ErrMsg            OUTPUT  
                  IF @b_Success <> 1   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 78334  
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispGenEOrderReplen03)'  
                     GOTO EXIT_SP           
                  END  
                  
                  SET @c_MoveRefKey = 'E' + RIGHT(@c_MoveRefKey, 9) 
                  
                  DECLARE @n_PDQty INT
                  DECLARE CUR_UPDATE_MOVE_REF CURSOR FAST_FORWARD READ_ONLY FOR  
                  SELECT P.PickDetailKey, p.Qty
                  FROM PICKDETAIL AS p WITH (NOLOCK)                    
                  JOIN Orders O (NOLOCK) ON O.OrderKey = p.OrderKey
                  WHERE P.[Status] = '0'  
                  AND   P.UOM IN ('6', '7')
                  AND   p.Storerkey = @c_StorerKey   
                  AND   p.Sku = @c_SKU        
                  AND   p.Loc = @c_FromLOC  
                  AND   p.Lot = @c_FromLOT
                  AND   p.ID  = @c_FromID
                  ORDER BY CASE WHEN ISNULL(O.LoadKey, '') = '' THEN 1 ELSE 2 END, p.Qty, p.AddDate DESC
                    
                  OPEN CUR_UPDATE_MOVE_REF  
                  FETCH NEXT FROM CUR_UPDATE_MOVE_REF INTO @c_PickDetailKey, @n_PDQty
                  WHILE @@FETCH_STATUS = 0 AND @n_QtyLockedToMove > 0
                  BEGIN  
                     IF @n_QtyLockedToMove >= @n_PDQty  
                     BEGIN  
                        UPDATE PICKDETAIL WITH (ROWLOCK)  
                        SET MoveRefKey = @c_MoveRefKey, EditDate = GETDATE(), TrafficCop = NULL    
                        WHERE PickDetailKey = @c_PickDetailKey  
                  
                         IF @@ERROR <> 0   
                         BEGIN  
                            SELECT @n_continue = 3  
                            SELECT @n_err = 78335  
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV16)'  
                         END   
                          
                        SET @n_QtyLockedToMove = @n_QtyLockedToMove - @n_PDQty                                                                        
                     END  
                     ELSE  
                     BEGIN  
                         SET @c_NewPickDetailKey = ''  
                                                
                         EXECUTE dbo.nspg_GetKey    
                            'PICKDETAILKEY',     
                            10 ,    
                            @c_NewPickDetailKey  OUTPUT,    
                            @b_success        OUTPUT,    
                            @n_err            OUTPUT,    
                            @c_errmsg         OUTPUT    
                           
                         IF @b_success <> 1    
                         BEGIN    
                            SET @n_Err = 78336    
                            SET @c_ErrMsg = 'Get Pickdetail Key'  
                            SET @n_Continue = 3  
                         END   
                                             
                         SET @n_SplitQty = @n_PDQty - @n_QtyLockedToMove 
                  
                         INSERT INTO PickDetail  
                         (  
                             PickDetailKey    ,CaseID           ,PickHeaderKey  
                            ,OrderKey         ,OrderLineNumber  ,Lot  
                            ,Storerkey        ,Sku              ,AltSku  
                            ,UOM              ,UOMQty           ,Qty  
                            ,QtyMoved         ,STATUS           ,DropID  
                            ,Loc              ,ID               ,PackKey  
                            ,UpdateSource     ,CartonGroup      ,CartonType  
                            ,ToLoc            ,DoReplenish      ,ReplenishZone  
                            ,DoCartonize      ,PickMethod       ,WaveKey  
                            ,EffectiveDate    ,TrafficCop       ,ArchiveCop  
                            ,OptimizeCop      ,ShipFlag         ,PickSlipNo  
                            ,Channel_ID   --WL01
                            )  
                         SELECT @c_NewPickDetailKey  AS PickDetailKey  
                               ,CaseID           ,PickHeaderKey    ,OrderKey  
                               ,OrderLineNumber  ,Lot              ,Storerkey  
                               ,Sku              ,AltSku           ,UOM
                               ,UOMQty           ,@n_SplitQty  
                               ,QtyMoved         ,[STATUS]         ,DropID         
                               ,Loc             ,ID                ,PackKey        
                               ,UpdateSource     ,CartonGroup      ,CartonType        
                               ,@c_PickDetailKey ,DoReplenish      ,ReplenishZone='SplitFrMoveRef'        
                               ,DoCartonize      ,PickMethod       ,WaveKey        
                               ,EffectiveDate    ,TrafficCop       ,ArchiveCop        
                               ,'9'              ,ShipFlag         ,PickSlipNo 
                               ,Channel_ID   --WL01 
                         FROM   PICKDETAIL WITH (NOLOCK)  
                         WHERE  PickDetailKey = @c_PickDetailKey   
                  
                         IF @@ERROR <> 0   
                         BEGIN  
                            SELECT @n_continue = 3  
                            SELECT @n_err = 78337  
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT PickDetail Failed! (ispRLWAV16)'  
                         END                     
                                             
                         UPDATE PICKDETAIL WITH (ROWLOCK)  
                         SET Qty = @n_QtyLockedToMove, 
                             MoveRefKey = @c_MoveRefKey,  
                             TrafficCop = NULL,  
                             ReplenishZone='Split2MoveRef'  
                         WHERE PickDetailKey = @c_PickDetailKey  
                  
                         IF @@ERROR <> 0   
                         BEGIN  
                            SELECT @n_continue = 3  
                            SELECT @n_err = 78338  
                            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispRLWAV16)'  
                         END   
                            
                         SET @n_QtyLockedToMove  = 0                     
                     END
                     
                     IF @@ERROR <> 0   
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 78339  
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'  
                        GOTO EXIT_SP           
                     END     
                             
                     FETCH NEXT FROM CUR_UPDATE_MOVE_REF INTO @c_PickDetailKey, @n_PDQty  
                  END  
                  CLOSE CUR_UPDATE_MOVE_REF  
                  DEALLOCATE CUR_UPDATE_MOVE_REF  
                  
                  -- Sum @n_QtyToTake with the Qty taken by others  
                  SET @n_QtyToTake = @n_QtyToTake + (@n_QtyLocked - @n_QtyLockedToMove)
                  
                  -- If PickDetail line not found, then reset MoveRefKey 
                  IF (@n_QtyLocked - @n_QtyLockedToMove) = 0
                     SET @c_MoveRefKey = 'ECOM'   --wawng02                 
               END
               -- NJOW04 (End)
               
               IF @b_Debug=1
               BEGIN             
                  PRINT '**    Found Location: ' + @c_FromLOC 
                  PRINT '      QtyAvailable: ' + CAST(@n_QtyAvailable AS VARCHAR(10))                         
                  PRINT '      FullCasePickQty: ' + CAST(@n_FullCasePickQty AS VARCHAR(10))                 
                  PRINT '      QtyToTake: ' + CAST(@n_QtyToTake AS VARCHAR(10))
               END 
                                 
               IF @n_QtyToTake > 0 
               BEGIN
                  EXECUTE nspg_GetKey
                     'REPLENISHKEY'
                  ,  10
                  ,  @c_ReplenishmentKey  OUTPUT
                  ,  @b_Success           OUTPUT 
                  ,  @n_Err               OUTPUT 
                  ,  @c_ErrMsg            OUTPUT
                  IF @b_Success <> 1 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78325
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END
                  
                  --SET @c_MoveRefKey = ''

                  IF @n_QtyInPickLoc > @n_QtyToTake
                     SET @n_QtyInPickLoc = @n_QtyToTake
                  ELSE 
                     SET @n_QtyInPickLoc = @n_ReplenQty          
                                                                                                   
                  INSERT INTO REPLENISHMENT(
                        Replenishmentgroup, ReplenishmentKey, StorerKey,
                        Sku,                FromLoc,          ToLoc,
                        Lot,                Id,               Qty,
                        UOM,                PackKey,          Confirmed, 
                        MoveRefKey,         ToID,             PendingMoveIn, 
                        QtyReplen,          QtyInPickLoc )
                  VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                           @c_SKU,                @c_FromLOC,          @c_LOC, 
                           @c_FromLOT,            @c_FromID,           @n_QtyToTake, 
                           @c_UOM,                @c_PackKey,          'N', 
                           @c_MoveRefKey,         @c_ToID,             @n_QtyToTake, 
                           @n_QtyToTake,          @n_QtyInPickLoc )  
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 78326
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (ispGenEOrderReplen03)'
                     GOTO EXIT_SP         
                  END 
                                    
               END      
                        
               SET @n_ReplenQty = @n_ReplenQty -  @n_QtyToTake
               SET @n_QtyInPickLoc = @n_QtyInPickLoc - @n_QtyToTake 
                              
               IF @b_Debug=1
               BEGIN             
                  PRINT '      Remain Replen Qty: ' + CAST(@n_ReplenQty AS VARCHAR(10))
               END 
               
               -- If not full case replen by LOT, get other LOT in same location 
               IF @n_RemainingFullCase > 0 AND @n_ReplenQty = 0 AND @cFastPickLoc = 'Y' 
               BEGIN
                  WHILE @n_RemainingFullCase > 0 
                  BEGIN
                     SET @c_FromLOT = '' 
                     SET @n_QtyAvailable = 0

                     IF @b_Debug=1
                     BEGIN
                        PRINT '>>    Find inventory with other LOT in Suggested Location when not full case'
                     END
                                          
                     SELECT TOP 1  
                        @c_FromLOC = LLI.LOC, 
                        @c_FromID  = LLI.ID, 
                        @n_QtyAvailable = LLI.Qty - (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0)), 
                        @c_FromLOT = LLI.LOT, 
                        @cFastPickLoc = 'Y' 
                     FROM LOTxLOCxID AS LLI WITH (NOLOCK) 
                     JOIN LOT WITH (NOLOCK) ON LOT.Lot = LLI.Lot 
                     JOIN LOC AS L WITH (NOLOCK) ON l.Loc = LLI.Loc 
                     JOIN SKUxLOC SL (NOLOCK) ON (SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey) 
                     JOIN ID (NOLOCK) ON (LLI.ID = ID.ID)
                     WHERE LOT.STATUS = 'OK' 
                     AND L.STATUS = 'OK' 
                     AND ID.STATUS = 'OK' 
                     AND L.LocationFlag = 'NONE' 
                     AND L.Facility = @c_Facility
                     AND LLI.StorerKey = @c_StorerKey 
                     AND LLI.Sku = @c_SKU       
                     AND LLI.LOC = @c_FromLOC         
                     AND LLI.Qty > (LLI.QtyPicked + LLI.QtyAllocated + ISNULL(LLI.QtyReplen, 0))               
                     ORDER BY L.LocationHandling, LLI.Qty   
                            
                     IF @c_FromLOT <> '' AND @n_QtyAvailable > 0 
                     BEGIN
                        IF @n_QtyAvailable >= @n_RemainingFullCase 
                           SET @n_QtyToTake = @n_RemainingFullCase
                        ELSE 
                           SET @n_QtyToTake = @n_QtyAvailable  
               
                        IF @b_Debug=1
                        BEGIN             
                           PRINT '**    Found LOT: ' + @c_FromLOT 
                           PRINT '      QtyAvailable: ' + CAST(@n_QtyAvailable AS VARCHAR(10))                         
                           PRINT '      RemainingFullCase: ' + CAST(@n_RemainingFullCase AS VARCHAR(10))                
                           PRINT '      QtyToTake: ' + CAST(@n_QtyToTake AS VARCHAR(10))
                        END 
                                 
                        IF @n_QtyToTake > 0 
                        BEGIN
                           EXECUTE nspg_GetKey
                              'REPLENISHKEY'
                           ,  10
                           ,  @c_ReplenishmentKey  OUTPUT
                           ,  @b_Success           OUTPUT 
                           ,  @n_Err               OUTPUT 
                           ,  @c_ErrMsg            OUTPUT
                           IF @b_Success <> 1 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @n_err = 78325
                              SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspg_GetKey Failed! (ispGenEOrderReplen03)'
                              GOTO EXIT_SP         
                           END
                  
                           SET @c_MoveRefKey = 'ECOM'  --WWANG02
                           SET @n_QtyInPickLoc = 0           
                                                                                                   
                           INSERT INTO REPLENISHMENT(
                                 Replenishmentgroup, ReplenishmentKey, StorerKey,
                                 Sku,                FromLoc,          ToLoc,
                                 Lot,                Id,               Qty,
      													 UOM,                PackKey,          Confirmed, 
                                 MoveRefKey,         ToID,             PendingMoveIn, 
                                 QtyReplen,          QtyInPickLoc )
                           VALUES (@c_ReplenishmentGroup, @c_ReplenishmentKey, @c_StorerKey, 
                                    @c_SKU,                @c_FromLOC,          @c_LOC, 
                                    @c_FromLOT,            @c_FromID,           @n_QtyToTake, 
                                    @c_UOM,                @c_PackKey,          'N', 
                                    @c_MoveRefKey,         @c_ToID,             @n_QtyToTake, 
                                    @n_QtyToTake,          @n_QtyInPickLoc )  
                           IF @@ERROR <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @n_err = 78326
                              SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Insert into Replenishment Failed! (ispGenEOrderReplen03)'
                              GOTO EXIT_SP         
                           END 
                           
                           SET @n_RemainingFullCase = @n_RemainingFullCase - @n_QtyToTake
                           
                           IF @n_RemainingFullCase <= 0 
                              BREAK          
                        END -- IF @n_QtyToTake > 0                               
                     END -- IF @c_FromLOT <> '' AND @n_QtyAvailable > 0 
                     ELSE 
                     BEGIN
                        SET @n_RemainingFullCase = 0 
                        BREAK
                     END
                                                                                 
                  END -- WHILE @n_RemainingFullCase > 0
               END
               
               IF @n_ReplenQty <= 0 
                  BREAK
            END
            ELSE 
            BEGIN
               SET @n_ReplenQty = 0 
               
               BREAK
            END                
               
         END  -- WHILE @@FETCH_STATUS = 0 (CUR_REPLEN_LOT)
      END -- IF @n_ReplenQty > 0 
      
      FETCH_NEXT:
      
      DECLARE CUR_UPDATE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT P.PickDetailKey
      FROM PICKDETAIL AS p WITH (NOLOCK) 
      JOIN @tTaskOrders AS PT   ON PT.OrderKey = P.OrderKey          
      WHERE P.[Status] = '0'
      AND   P.UOM = '7'  
      AND   P.DoReplenish = 'N' 
      AND   p.Storerkey = @c_StorerKey 
      AND   p.Sku = @c_SKU      
      AND   p.Loc = @c_LOC
      
      OPEN CUR_UPDATE
      FETCH NEXT FROM CUR_UPDATE INTO @c_PickDetailKey
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK)
            SET DoReplenish = 'Y', EditDate = GETDATE(), TrafficCop = NULL  
         WHERE PickDetailKey = @c_PickDetailKey
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78327
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update PickDetail Failed! (ispGenEOrderReplen03)'
            GOTO EXIT_SP         
         END   
               
         FETCH NEXT FROM CUR_UPDATE INTO @c_PickDetailKey
      END
      CLOSE CUR_UPDATE
      DEALLOCATE CUR_UPDATE 
      
      FETCH NEXT FROM CUR_OVERALLOCATE_LOC INTO @c_Facility, @c_StorerKey ,@c_SKU, @c_LOC, @n_ReplenQty, @n_LocCapacity   
   END
   CLOSE CUR_OVERALLOCATE_LOC
   DEALLOCATE CUR_OVERALLOCATE_LOC

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   BEGIN TRAN
             
   IF EXISTS(SELECT 1 FROM REPLENISHMENT WITH (NOLOCK)
             WHERE ReplenishmentGroup = @c_ReplenishmentGroup) OR
      dbo.fnc_GetRight(@c_facility, @c_Storerkey, '', 'NoReplenStillGenReplenGroup') = '1'         
   BEGIN
      DECLARE cur_PackTask_RowRef CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT pt.RowRef 
      FROM PackTask AS pt WITH(NOLOCK)        
      JOIN @tTaskBatchNo TBN ON TBN.TaskBatchNo = pt.TaskBatchNo
      WHERE pt.ReplenishmentGroup = '' OR pt.ReplenishmentGroup IS NULL 
   
      OPEN cur_PackTask_RowRef
   
      FETCH FROM cur_PackTask_RowRef INTO @n_RowRef 
   
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PackTask WITH (ROWLOCK) 
            SET ReplenishmentGroup = @c_ReplenishmentGroup, 
                EditWho = SUSER_SNAME(),
                EditDate = GETDATE()
         WHERE RowRef = @n_RowRef 
         IF @@ERROR <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 78328
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Updating PackTask Failed! (ispGenEOrderReplen03)'
            GOTO EXIT_SP         
         END
         
         FETCH FROM cur_PackTask_RowRef INTO @n_RowRef 
      END
   
      CLOSE cur_PackTask_RowRef
      DEALLOCATE cur_PackTask_RowRef    
      
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      BEGIN TRAN
      
      SET @c_PostGenEOrderReplenSP = ''
      SET @b_success = 0
      EXECUTE nspGetRight
               @c_facility       -- facility
            ,  @c_Storerkey               -- Storerkey
            ,  ''                         -- Sku
            ,  'PostGenEOrderReplenSP'    -- Configkey
            ,  @b_success                 OUTPUT
            ,  @c_PostGenEOrderReplenSP   OUTPUT
            ,  @n_err                     OUTPUT
            ,  @c_errmsg                  OUTPUT
      
      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 78332
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (ispGenEOrderReplen03)'
         GOTO EXIT_SP      
      END      

      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostGenEOrderReplenSP AND TYPE = 'P')
      BEGIN
         SET @c_SQL = N'EXECUTE ' + @c_PostGenEOrderReplenSP  
                     + '  @c_ReplenishmentGroup = @c_ReplenishmentGroup' 
                     + ', @b_Success    = @b_Success     OUTPUT' 
                     + ', @n_Err        = @n_Err         OUTPUT'  
                     + ', @c_ErrMsg     = @c_ErrMsg      OUTPUT'  

         SET @c_SQLParms= N' @c_ReplenishmentGroup NVARCHAR(10)'  
                        +  ',@b_Success            INT OUTPUT'
                        +  ',@n_Err                INT OUTPUT'
                        +  ',@c_ErrMsg             NVARCHAR(250) OUTPUT'
                                 
         EXEC sp_ExecuteSQL @c_SQL
                        ,   @c_SQLParms
                        ,   @c_ReplenishmentGroup
                        ,   @b_Success    OUTPUT
                        ,   @n_Err        OUTPUT
                        ,   @c_ErrMsg     OUTPUT 
  
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 78333    
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostGenEOrderReplenSP 
                           + '.(ispGenEOrderReplen03)'
                           + CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END 
            GOTO EXIT_SP                          
         END 
      END
   END
   

   IF @b_Debug=1
   BEGIN
      PRINT ''
      PRINT '  ****   End   ****'
      PRINT ''
      SELECT * FROM REPLENISHMENT AS r WITH(NOLOCK)
      WHERE r.ReplenishmentGroup = @c_ReplenishmentGroup    
   END
      
   EXIT_SP:     
   IF CURSOR_STATUS('LOCAL' , 'CUR_REPLEN_LOT') in (0 , 1)
   BEGIN
      CLOSE CUR_REPLEN_LOT
      DEALLOCATE CUR_REPLEN_LOT
   END 
   IF CURSOR_STATUS('LOCAL' , 'CUR_OVERALLOCATE_LOC') in (0 , 1)
   BEGIN
      CLOSE CUR_OVERALLOCATE_LOC
      DEALLOCATE CUR_OVERALLOCATE_LOC
   END

       
   IF @n_Continue = 3 
   BEGIN
       SET @b_Success = 0                                                                                                                                        
    
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
       BEGIN
           ROLLBACK TRAN
       END
       ELSE
       BEGIN
           WHILE @@TRANCOUNT > @n_StartTCnt
           BEGIN
               COMMIT TRAN
           END
       END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
          COMMIT TRAN
      END
   END       
         
   WHILE @@TRANCOUNT < @n_StartTCnt 
      BEGIN TRAN         
      
END

GO