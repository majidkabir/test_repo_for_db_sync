SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Stored Procedure: ispWRUCC02                                                 */
/* Creation Date: 05-May-2015                                                   */
/* Copyright: LF Logistics                                                      */
/* Written by: Shong                                                            */
/*                                                                              */
/* Purpose: SOS-340638 ToryBurch HK SAP - UCC allocation                        */
/*          Original: ispWaveReplenUCCAlloc                                     */
/*                                                                              */
/* Called By: ispWaveReplenUCCAlloc with StorerConfig                           */
/*                                                                              */
/* PVCS Version: 1.1                                                            */
/*                                                                              */
/* Version: 5.4                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date         Author     Ver     Purposes                                     */
/* 14-Sep-2006  Shong      1.0     SOS58649 - Found "HOLD" Lot items can be     */
/* 06-Aug-2015  TLTING01   1.1     Blocking Tune                                */
/* 20-Feb-2017  TLTING02   1.2     Bug fix                                      */
/* 05-Jun-2020  NJOW02     1.3     WMS-13528 filtering and sorting by codelkup  */                                            
/* 08-Jun-2023  NJOW03     1.4     WMS-22674 add multi-sku UCC allocation       */
/* 21-Aug-2023  NJOW03     1.4     DEVOPS Combine Script                        */
/********************************************************************************/

CREATE   PROCEDURE [dbo].[ispWRUCC02]
   @c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS    
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue int  ,  /* continuation flag
                           1=Continue
                           2=failed but continue processsing
                           3=failed do not continue processing
                           4=successful but skip furthur processing */
            @n_starttcnt int        , -- Holds the current transaction count
            @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
            @n_err2 int,              -- For Additional Error Detection
            @b_debug int              -- Debug Flag

   /* Declare RF Specific Variables */
   IF @b_success = 5
   BEGIN
      SET @b_debug = 1
      SET @b_success = 1
   END
   ELSE
      SELECT @b_debug = 0

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0


   DECLARE  @c_TaskID         NVARCHAR(25),
            @b_NewLocation    INT,
            @c_TransmitlogKey NVARCHAR(10),
            @c_country        NVARCHAR(30),
            @c_COO            NVARCHAR(18), -- lottable01
       		  @c_ZipCodeTo	    NVARCHAR(15)
        
   IF @n_starttcnt = 0 
      BEGIN TRAN
   
   -- Validation
   IF @n_continue=1 OR @n_continue=2
   BEGIN
   	 IF EXISTS (SELECT 1 
                 FROM  REPLENISHMENT WITH (NOLOCK)
                 WHERE ReplenNo = @c_WaveKey 
                 AND Confirmed = 'S')
   --              AND Confirmed <> 'N')
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Replenishment Has Been Started. Re-Generate Replenishment Is Not Allowed. (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
          GOTO RETURN_SP
      END
      
      /*
      IF EXISTS (SELECT 1 
                 FROM WAVEDETAIL (NOLOCK)
                 JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
                 WHERE WAVEDETAIL.Wavekey = @c_WaveKey 
                 AND PICKDETAIL.Status >= '5')
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Replenishment Has Been Started. Re-Generate Replenishment Is Not Allowed. (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
          GOTO RETURN_SP
      END 
      */  	
   END
         
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SET @c_TaskId = ''
      
      SELECT TOP 1 
         @c_TaskId = r.ReplenishmentGroup 
      FROM  REPLENISHMENT r WITH (NOLOCK)
      WHERE r.ReplenNo = @c_WaveKey 
      
      IF ISNULL(RTRIM(@c_TaskId),'') = ''
      BEGIN
        EXECUTE nspg_GetKey
             @keyname       = 'REPLENISHGROUP',
             @fieldlength   = 10,
             @keystring     = @c_taskid    OUTPUT,
             @b_success     = @b_success   OUTPUT,
             @n_err         = @n_err       OUTPUT,
             @c_errmsg      = @c_errmsg    OUTPUT
        IF NOT @b_success = 1
        BEGIN
             SELECT @n_continue = 3
        END      
      END
   END
   
   --Initialization
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE  @c_Facility          NVARCHAR(5)
      ,        @c_Sku               NVARCHAR(20)
      ,        @c_StorerKey         NVARCHAR(15)
      ,        @n_OpenQty           int
      ,        @n_QtyAllocated      int
      ,        @n_QtyPicked         int
      ,        @n_QtyReplenish      int
      ,        @c_UOM               NVARCHAR(5)
      ,        @c_PackKey           NVARCHAR(10)
      ,        @c_Status            NVARCHAR(1)
      ,        @c_Lottable01        NVARCHAR(18)
      ,        @c_Lottable02        NVARCHAR(18)
      ,        @c_SysLottable01     NVARCHAR(18)
      ,        @c_Lottable03        NVARCHAR(18)
      ,        @d_Lottable04        DATETIME
      ,        @d_Lottable05        DATETIME
      ,        @c_Lottable06        NVARCHAR(30)  
      ,        @c_Lottable07        NVARCHAR(30)  
      ,        @c_Lottable08        NVARCHAR(30)  
      ,        @c_Lottable09        NVARCHAR(30)  
      ,        @c_Lottable10        NVARCHAR(30)  
      ,        @c_Lottable11        NVARCHAR(30)  
      ,        @c_Lottable12        NVARCHAR(30)  
      ,        @d_Lottable13        DATETIME  
      ,        @d_Lottable14        DATETIME  
      ,        @d_Lottable15        DATETIME  
      ,        @c_Lottable01Label   NVARCHAR(18)
      ,        @c_Lottable02Label   NVARCHAR(18)
      ,        @c_Lottable03Label   NVARCHAR(18)
      ,        @c_Lottable04Label   NVARCHAR(18)
      ,        @c_Lottable05Label   NVARCHAR(18)
      ,        @c_Lottable06Label   NVARCHAR(18)  
      ,        @c_Lottable07Label   NVARCHAR(18)  
      ,        @c_Lottable08Label   NVARCHAR(18)  
      ,        @c_Lottable09Label   NVARCHAR(18)  
      ,        @c_Lottable10Label   NVARCHAR(18)  
      ,        @c_Lottable11Label   NVARCHAR(18)  
      ,        @c_Lottable12Label   NVARCHAR(18)  
      ,        @c_Lottable13Label   NVARCHAR(18)  
      ,        @c_Lottable14Label   NVARCHAR(18)  
      ,        @c_Lottable15Label   NVARCHAR(18)  
      ,        @c_OrderLineIdx      NVARCHAR(15)
      ,        @c_OrderKey          NVARCHAR(10)
      ,        @c_OrderLineNumber   NVARCHAR(5)
      ,        @c_ExecStatement     NVARCHAR(MAX)
      ,        @n_CursorOpen        int
      ,        @c_UCCNo             NVARCHAR(20)
      ,        @c_LOT               NVARCHAR(10)
      ,        @c_LOC               NVARCHAR(10)
      ,        @c_ID                NVARCHAR(18)
      ,        @n_UCC_Qty           int
      ,        @n_QtyLeftToFulfill  int
      ,        @c_PickDetailKey     NVARCHAR(10)
      ,        @n_Cnt_SQL           int
      ,        @b_PickInsertSuccess int
      ,        @c_ReplenishmentKey  NVARCHAR(10)
      ,        @c_PutawayZone       NVARCHAR(10)
      ,        @c_ToLoc             NVARCHAR(10)
      ,        @n_LOT_Qty           int
      ,        @n_AllocateQty       int
      ,        @c_PrevOrderkey      NVARCHAR(10)
      ,        @c_PickSlipNo        NVARCHAR(10)
      ,        @c_LabelNo           NVARCHAR(20)
      ,        @n_Carton            int
      ,        @c_Zone              NVARCHAR(10)
      ,        @c_DynamicLocLoop    NVARCHAR(5)
      ,        @n_QtyInPickLOC      int 
      ,        @c_PrevPutAwayZone   NVARCHAR(10)       
   
      --NJOW01
      DECLARE  @c_FoundReplenishmentkey NVARCHAR(10)
      ,        @n_ReplenAvailableQty    INT
      ,        @c_ExecStatement2        NVARCHAR(MAX)                                
      ,        @c_filter_long           NVARCHAR(255) 
      ,        @c_filter_notes          NVARCHAR(2000) 
      ,        @c_Sort_notes2           NVARCHAR(1000) 
      ,        @c_c_Country             NVARCHAR(30) 
      ,        @c_OrderGroup            NVARCHAR(20)   --NJOW02
      
      --NJOW03 S 		  
      DECLARE @c_LabelLine           NVARCHAR(5),
              @n_UCCCartonNo         INT,   
              @n_UCCQty              INT,
              @n_UCCQtyAllocated     INT,              
              @c_OrderLineNumber_rev NVARCHAR(5), 
              @n_Qty_rev             INT, 
              @c_MultiUCCToLoc       NVARCHAR(10),
              @n_UCC_Qty2            INT,
              @n_OpenQty2            INT,
              @n_FetchStatus         INT
              
              
      CREATE TABLE #TMP_UCCPICK (RowID           INT IDENTITY(1,1) PRIMARY KEY,
                                 UCCNo NVARCHAR(20),
                                 Sku   NVARCHAR(20) NULL,
                                 Lot   NVARCHAR(10) NULL,
                                 Loc   NVARCHAR(10) NULL,
                                 ID    NVARCHAR(18) NULL,
                                 Qty   INT)     
      CREATE INDEX IDX_UCCSKU ON #TMP_UCCPICK (UCCNo, Sku)                                                                           
      --NJOW03 E                           
                      
      DECLARE @n_Pickslip_cnt INT  
      DECLARE @n_PickSlipNo INT  
      DECLARE @c_TPickSlipNo NVARCHAR(10)  
            
      --NJOW01 S
      SELECT TOP 1 @c_Storerkey = O.Storerkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      AND WD.Wavekey = @c_Wavekey
      
      SELECT TOP 1 @c_Filter_long = CL.Long,
                   @c_Filter_notes = CL.Notes,
                   @c_Sort_Notes2 = CL.Notes2,
                   @c_MultiUCCToLoc = SC.Option2  --NJOW03
      FROM CODELKUP CL (NOLOCK)
      JOIN STORERCONFIG SC (NOLOCK) ON CL.Code = SC.Option1 
      WHERE CL.ListName = 'ALLOCPREF'
      AND SC.Configkey = 'WaveReplenUCCAllocation_SP'
      AND SC.Storerkey = @c_Storerkey
      --NJOW01 E
   
      IF EXISTS ( SELECT 1 from WaveOrderLn WITH(NOLOCK)   
               WHERE WaveOrderLn.WaveKey = @c_WaveKey )
      BEGIN
         DELETE WaveOrderLn WITH(ROWLOCK)   
         WHERE WaveOrderLn.WaveKey = @c_WaveKey  --GOH01  
      END
             
      UPDATE UCC WITH(ROWLOCK) --GOH01
      SET    STATUS = '2'
            ,WaveKey = ''
            ,EditDate = GETDATE()
            ,EditWho = SUSER_SNAME()
      FROM   UCC
             JOIN REPLENISHMENT(NOLOCK)
                  ON  UCC.uccno = REPLENISHMENT.refno
      WHERE  REPLENISHMENT.replenno = @c_WaveKey
      AND    REPLENISHMENT.Confirmed = 'N'
      AND    REPLENISHMENT.ToLoc <> 'PICK'
      AND    (UCC.status = '3' OR UCC.Status = '6')    
          
      DELETE Replenishment WITH(ROWLOCK) --GOH01
      WHERE  ReplenNo = @c_WaveKey
      AND    Confirmed = 'N'
      AND    ToLoc <> 'PICK'
   END  

   --tlting01
   IF @b_debug = 0
   BEGIN
     WHILE @@TRANCOUNT > 0
        COMMIT TRAN
     
     BEGIN TRAN                         
   END
   	
   --Generate pickslipno
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --GOH01 Start  
      DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY 
      FOR
          SELECT DISTINCT ORDERS.OrderKey
          FROM   WAVEDETAIL(NOLOCK)
                 JOIN ORDERS WITH (NOLOCK)
                      ON  (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
                 JOIN ORDERDETAIL WITH (NOLOCK)
                      ON  (
                              ORDERDETAIL.OrderKey = WAVEDETAIL.OrderKey
                          AND ORDERDETAIL.OrderKey = ORDERS.OrderKey
                          )
          WHERE  WAVEDETAIL.WaveKey = @c_WaveKey
          AND    ORDERS.Status <> '9'
          AND    ORDERS.Type NOT IN ('M' ,'I')
     
      OPEN CUR_WaveOrder   
        
      FETCH NEXT FROM CUR_WaveOrder INTO  @c_OrderKey
        
      WHILE @@FETCH_STATUS <> -1
      AND   (@n_continue = 1 OR @n_continue = 2)
      BEGIN
          SELECT @c_Pickslipno = ''  
          
          SELECT @c_Pickslipno = Pickheaderkey
          FROM   PICKHEADER(NOLOCK)
          WHERE  Orderkey = @c_Orderkey  
          
          IF ISNULL(@c_PickslipNo ,'') = ''
          BEGIN
              IF (@n_continue = 1 OR @n_continue = 2)
                  SELECT @b_success = 0 
                  EXECUTE nspg_getkey 
                  'PICKSLIP' 
                  , 9 
                  , @c_PickSlipNo OUTPUT 
                  , @b_success OUTPUT 
                  , @n_err OUTPUT 
                  , @c_errmsg OUTPUT  
                  
                  IF @b_success = 1
                      SELECT @c_PickSlipNo = 'P' + RTRIM(@c_PickSlipNo)
                  ELSE
                      BREAK
              
              INSERT PickHeader
                (
                  Pickheaderkey
                 ,Wavekey
                 ,Orderkey
                 ,zone
                 ,picktype
                )
              VALUES
                (
                  @c_PickSlipNo
                 ,@c_Wavekey
                 ,@c_Orderkey
                 ,'3'
                 ,'0'
                )
          END 
          
          FETCH NEXT FROM CUR_WaveOrder INTO @c_OrderKey
      END -- while  cursor  
      CLOSE CUR_WaveOrder  
      DEALLOCATE CUR_WaveOrder  
   END
   
   --tlting01
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      
      BEGIN TRAN      
   END

   -- Start inserting the records into Temp WaveOrderLine   	
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN   
      SET @c_OrderKey = ''   
      
      --NJOW01
      SET @c_ExecStatement = N'
         INSERT INTO WaveOrderLn (Facility,                     WaveKey,            OrderKey,
                                  OrderLineNumber,              Sku,                StorerKey,
                                  OpenQty,                      QtyAllocated,       QtyPicked,
                                  QtyReplenish,                 UOM,                PackKey,
                                  Status,                       Lottable01,         Lottable02,
                                  Lottable03,                   Lottable04,         Lottable05,
                                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,   
                                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)                                
                           SELECT ORDERS.Facility,              WAVEDETAIL.WaveKey, ORDERS.OrderKey,
                                  ORDERDETAIL.OrderLineNumber,  ORDERDETAIL.Sku,    ORDERDETAIL.StorerKey,
                                  (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked),
                                  0,                            0,
                                  0,                            ORDERDETAIL.UOM,             ORDERDETAIL.PackKey, ' +
                                  CASE WHEN ISNULL(@c_Filter_long,'') <> '' AND ISNULL(@c_Filter_Notes,'') <> '' THEN   
                                     ' CASE WHEN ' + RTRIM(@c_Filter_long) + ' THEN ''F'' ELSE ''0'' END, ' ELSE '0,' END +    --ORDERDETAIL.Status --NJOW01
                                 ' ORDERDETAIL.Lottable01,      ISNULL(ORDERDETAIL.Lottable02,''''),
                                   ISNULL(ORDERDETAIL.Lottable03,''''),   ORDERDETAIL.Lottable04,  ORDERDETAIL.Lottable05
                                 , ISNULL(ORDERDETAIL.Lottable06,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable07,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable08,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable09,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable10,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable11,'''')  
                                 , ISNULL(ORDERDETAIL.Lottable12,'''')  
                                 , ORDERDETAIL.Lottable13  
                                 , ORDERDETAIL.Lottable14  
                                 , ORDERDETAIL.Lottable15                                  
         FROM  WAVEDETAIL (NOLOCK)
         JOIN  ORDERS WITH(NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)  --GOH01  
         JOIN  ORDERDETAIL WITH(NOLOCK) ON (ORDERDETAIL.OrderKey = WAVEDETAIL.OrderKey AND ORDERDETAIL.OrderKey = ORDERS.OrderKey)  --GOH01  
         WHERE WAVEDETAIL.WaveKey = @c_WaveKey
         AND   ORDERS.Status <> ''9''
         AND   ORDERS.Type NOT IN (''M'', ''I'')
         AND   OrderDetail.OpenQty - ( OrderDetail.QtyAllocated + OrderDetail.QtyPreAllocated + OrderDetail.QtyPicked) > 0 '
       
         EXEC sp_executesql @c_ExecStatement,
            N'@c_Wavekey NVARCHAR(10)', 
            @c_Wavekey
   END      

   --Allocate Full Carton (UCC)
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN            
      -- Loop 1 Lottable01
      IF (@b_debug = 1 or @b_debug = 2)
      BEGIN
         Print 'Start Allocate Full Carton (UCC)..'   --full UCC pick from bulk. by order. generate pickdetail(FCP)
      END
         
      SELECT @c_PrevOrderKey = ''
      SELECT @c_OrderLineIdx = ''
      SELECT @n_Carton = 0
   
      DECLARE CUR_WaveDetLn CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT WaveOrderLn.OrderKey,  WaveOrderLn.OrderLineNumber
         FROM   WaveOrderLn (NOLOCK)
         WHERE WaveOrderLn.WaveKey = @c_WaveKey   
         ORDER BY WaveOrderLn.OrderKey,  WaveOrderLn.OrderLineNumber      

      OPEN CUR_WaveDetLn 
      
      FETCH NEXT FROM CUR_WaveDetLn INTO @c_OrderKey, @c_OrderLineNumber      
      SET @n_FetchStatus = @@FETCH_STATUS  --NJOW03
      
      WHILE @n_FetchStatus  <> -1 AND (@n_continue=1 OR @n_continue=2)  --NJOW03
      BEGIN
         --tlting01
         IF @b_debug = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
            
            BEGIN TRAN         	
         END

		   	 --Generate transmitlog
   		   IF @c_PrevOrderKey <> @c_OrderKey
   		   BEGIN
   		      SELECT @c_StorerKey = ORDERS.StorerKey,
      	    			 @c_ZipCodeTo = ROUTEMASTER.ZipCodeTo,
   		  	         @c_country = RTRIM(ORDERS.C_Country)
   		      FROM ORDERS (NOLOCK)
        	  LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON ORDERS.Route = ROUTEMASTER.Route			     
   		      WHERE ORDERS.OrderKey = @c_OrderKey
          
            IF EXISTS(SELECT 1 
   		   	            FROM StorerConfig (NOLOCK)
   		   	            WHERE ConfigKey = 'ECCOHK_MANUALORD' 
   		   	            AND sValue = '1'
                      AND StorerKey = @c_StorerKey) 
            OR EXISTS(SELECT 1 
   		  		          FROM StorerConfig (NOLOCK)
   		  		          WHERE ConfigKey = 'TBLHK_MANUALORD' 
   		  		          AND sValue = '1'
            		      AND StorerKey = @c_StorerKey
                      AND ISNULL(@c_ZipCodeTo,'') <> 'EXP'
   		  	            AND @c_country IN('HK','MO'))
   		   	  BEGIN
   		   	  	 IF NOT EXISTS (SELECT 1 FROM Transmitlog (NOLOCK) WHERE TableName = 'NIKEHKMORD' AND Key1 = @c_OrderKey)  
   		         BEGIN
   		            SELECT @c_Transmitlogkey=''
   		            SELECT @b_success=1
                
   		            EXECUTE nspg_getkey
   		               'TransmitlogKey'
   		               ,10
   		               , @c_TransmitlogKey OUTPUT
   		               , @b_success OUTPUT
   		               , @n_err OUTPUT
   		               , @c_errmsg OUTPUT
   		               
   		            IF NOT @b_success=1
   		            BEGIN
   		               SELECT @n_continue=3
   		               SELECT @n_err = @@ERROR
   		               SELECT @c_errMsg = 'Error Found When Generating TransmitLogKey (ispWRUCC02)'
   		            END
   		            ELSE
   		            BEGIN
   		               INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3)
   		               VALUES (@c_TransmitlogKey, 'NIKEHKMORD', @c_OrderKey, '', @c_StorerKey )
                
   		               IF @@ERROR <> 0
   		               BEGIN
   		                  SELECT @n_continue=3
   		                  SELECT @n_err = @@ERROR
   		                  SELECT @c_errMsg = 'Insert into TransmitLog Failed (ispWRUCC02)'
   		               END
   		            END
   		         END
   		   	  END								
   		   END
      	         
      	 --Get pickslipno
         IF @c_PrevOrderkey <> @c_Orderkey
         BEGIN
            SELECT @c_Pickslipno = ''
            SELECT @c_Pickslipno = Pickheaderkey 
            FROM PICKHEADER (NOLOCK)
            WHERE Orderkey = @c_Orderkey
                          
            IF ISNULL(RTRIM(@c_PickslipNo),'') = ''
            BEGIN
               SELECT @b_success = 0
               EXECUTE   nspg_getkey
                 'PICKSLIP'
                 , 9
                 , @c_PickSlipNo OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
               
               IF ISNULL(RTRIM(@c_PickslipNo),'') <> ''
                 SELECT @c_PickSlipNo = 'P' + RTRIM(@c_PickSlipNo)
               ELSE
                 BREAK
                
               INSERT PickHeader (Pickheaderkey, Wavekey, Orderkey, zone, picktype)
               VALUES (@c_PickSlipNo, @c_Wavekey, @c_Orderkey, '3','0')
            END                     
         END
          
         --Get order line detail info    
         SELECT @c_Facility     = WaveOrderLn.Facility,
                @c_WaveKey      = WaveOrderLn.WaveKey,
                @c_Sku          = WaveOrderLn.SKU,
                @c_StorerKey    = WaveOrderLn.StorerKey,
                @n_OpenQty      = WaveOrderLn.OpenQty,
                @n_QtyAllocated = WaveOrderLn.QtyAllocated,
                @n_QtyPicked    = WaveOrderLn.QtyPicked,
                @n_QtyReplenish = WaveOrderLn.QtyReplenish,
                @c_UOM          = WaveOrderLn.UOM,
                @c_PackKey      = WaveOrderLn.PackKey,
                @c_Status       = WaveOrderLn.Status,
                @c_Lottable01   = WaveOrderLn.Lottable01,
                @c_Lottable02   = WaveOrderLn.Lottable02,
                @c_Lottable03   = WaveOrderLn.Lottable03,
                @d_Lottable04   = WaveOrderLn.Lottable04,
                @d_Lottable05   = WaveOrderLn.Lottable05,
                @c_Lottable06   = WaveOrderLn.Lottable06,  
                @c_Lottable07   = WaveOrderLn.Lottable07,  
                @c_Lottable08   = WaveOrderLn.Lottable08,  
                @c_Lottable09   = WaveOrderLn.Lottable09,  
                @c_Lottable10   = WaveOrderLn.Lottable10,  
                @c_Lottable11   = WaveOrderLn.Lottable11,  
                @c_Lottable12   = WaveOrderLn.Lottable12,  
                @d_Lottable13   = WaveOrderLn.Lottable13,  
                @d_Lottable14   = WaveOrderLn.Lottable14,  
                @d_Lottable15   = WaveOrderLn.Lottable15,  
                @c_Lottable01Label = SKU.Lottable01Label,
                @c_Lottable02Label = SKU.Lottable02Label,
                @c_Lottable03Label = SKU.Lottable03Label,
                @c_Lottable04Label = SKU.Lottable04Label,
                @c_Lottable05Label = SKU.Lottable05Label,
                @c_Lottable06Label = SKU.Lottable06Label,  
                @c_Lottable07Label = SKU.Lottable07Label,  
                @c_Lottable08Label = SKU.Lottable08Label,  
                @c_Lottable09Label = SKU.Lottable09Label,  
                @c_Lottable10Label = SKU.Lottable10Label,  
                @c_Lottable11Label = SKU.Lottable11Label,  
                @c_Lottable12Label = SKU.Lottable12Label,  
                @c_Lottable13Label = SKU.Lottable13Label,  
                @c_Lottable14Label = SKU.Lottable14Label,  
                @c_Lottable15Label = SKU.Lottable15Label,
                @c_c_Country = ORDERS.c_Country,   --NJOW01
                @c_OrderGroup = ORDERS.OrderGroup  --NJOW02                
         FROM WaveOrderLn (NOLOCK)
         JOIN ORDERS (NOLOCK) ON WaveOrderLn.Orderkey = ORDERS.Orderkey --NJOW01
         JOIN  SKU (NOLOCK) ON (SKU.StorerKey = WaveOrderLn.StorerKey AND SKU.SKU = WaveOrderLn.SKU)         
         WHERE WaveOrderLn.OrderKey = @c_OrderKey
         AND   WaveOrderLn.OrderLineNumber = @c_OrderLineNumber
            
         --Check if full ucc available for the order line qty
         IF NOT EXISTS(SELECT 1 FROM UCC (NOLOCK)
                       WHERE UCC.StorerKey = @c_StorerKey
                       AND   UCC.SKU = @c_SKU
                       AND   UCC.Status BETWEEN '1' AND '2'
                       AND   UCC.Qty <= @n_OpenQty )
         BEGIN
            --FETCH NEXT FROM CUR_WaveDetLn INTO @c_OrderKey, @c_OrderLineNumber  
            --CONTINUE
            GOTO FETCH_NEXT_ORDERLINE
         END
            
         TRUNCATE TABLE #TMP_UCCPICK --NJOW03
         
         SELECT @c_ExecStatement =
            --'DECLARE UCCPickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
            'INSERT INTO #TMP_UCCPICK (UCCNo, Lot, SKU, Loc, ID, Qty) ' +  --NJOW03
            'SELECT UCC.UCCNo, UCC.Lot, UCC.Sku, UCC.Loc, UCC.ID, UCC.Qty ' +
            'FROM UCC (NOLOCK) ' +
            'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
            'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
            'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
            'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
            'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
            'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
            'OUTER APPLY (SELECT TOP 1 U.UCCNo
                          FROM UCC U(NOLOCK) 
                          WHERE U.UCCNo = UCC.UCCNo 
                          AND U.Storerkey = UCC.Storerkey
                          AND U.Orderkey = @c_Orderkey) ORDUCC ' +  --NJOW03            
            'WHERE UCC.StorerKey = N''' + RTrim(@c_StorerKey) + ''' ' +
            'AND   UCC.SKU = N''' + RTrim(@c_SKU) + ''' ' +
            'AND   UCC.Status BETWEEN ''1'' AND ''2'' ' +
            'AND   UCC.Qty <= ' + CAST(@n_OpenQty as NVARCHAR(10)) + ' ' +
            'AND   UCC.Qty > 0 ' +
            'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
            'AND   LOC.LocationType = ''OTHER'' ' +
            'AND   LOC.LocationFlag <> ''HOLD'' ' +
            'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
            'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '
      
         IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
         BEGIN
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                   ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
         END
      
         IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '  
            
         --NJOW01
         IF @c_Status = 'F'
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND ' + RTRIM(@c_Filter_Notes) + ' '  
   
         IF ISNULL(@c_Sort_Notes2,'') <> ''  --NJOW01
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' ORDER BY CASE WHEN ORDUCC.UCCNo IS NOT NULL THEN 1 ELSE 2 END, ' + RTRIM(@c_Sort_Notes2) --NJOW03
         ELSE   
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                ' ORDER By CASE WHEN ORDUCC.UCCNo IS NOT NULL THEN 1 ELSE 2 END, LotAttribute.Lottable05, LotAttribute.lot, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '  --NJOW03
   
         IF (@b_debug = 2)
         BEGIN
            Print @c_ExecStatement
         END

         --EXEC sp_executesql @c_ExecStatement
         EXEC sp_executesql @c_ExecStatement,   --NJOW01
            N'@c_c_Country NVARCHAR(30), @c_OrderGroup NVARCHAR(20), @c_Orderkey NVARCHAR(10)',  --NJOW02 NJOW03
              @c_c_Country,
              @c_OrderGroup,  --NJOW02
              @c_Orderkey --NJOW03
              
         DECLARE UCCPickCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    --NJOW03
            SELECT UCCNo, Lot, Loc, ID, Qty
            FROM #TMP_UCCPICK
            ORDER BY RowID
   
         OPEN UCCPickCursor
   
         --Create packheader
         IF NOT EXISTS(SELECT 1 FROM PackHeader (NOLOCK) 
                       WHERE PickSlipNo = @c_PickSlipNo 
                       AND   OrderKey   = @c_OrderKey)
         BEGIN   
            INSERT PackHeader (PickSlipNo, StorerKey, OrderKey, OrderRefNo, ConsigneeKey, Loadkey, Route)
               SELECT @c_PickSlipNo, StorerKey, OrderKey, ExternOrderKey, ConsigneeKey, @c_WaveKey, Route
               FROM ORDERS (NOLOCK)
               WHERE OrderKey = @c_OrderKey
   
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err = @@ERROR
               SELECT @c_errMsg = 'Insert into PackHeader Failed (ispWRUCC02)'
               CLOSE UCCPickCursor
               DEALLOCATE UCCPickCursor
               GOTO RETURN_SP
            END
         END -- Not exists in PackHeader
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16905
         BEGIN
            CLOSE UCCPickCursor
            DEALLOCATE UCCPickCursor
         END
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63530   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO RETURN_SP
         END
         ELSE
         BEGIN
            SELECT @n_CursorOpen = 1
         END
   
         SELECT @n_QtyLeftToFulfill = @n_OpenQty
   
         FETCH NEXT FROM UCCPickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
   
         WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
         BEGIN
         	  --NJOW03 
         	  IF EXISTS(SELECT 1
         	            FROM UCC U (NOLOCK)
         	            LEFT JOIN WaveOrderLn OD (NOLOCK) ON U.Storerkey = OD.Storerkey AND U.Sku = OD.SKU 
         	                                         AND U.Qty <= OD.OpenQty
         	                                         AND OD.Orderkey = @c_Orderkey
         	                                         AND OD.Wavekey = @c_Wavekey
         	            WHERE U.UCCNo = @c_UCCNo
         	            AND U.Status < '3'
         	            AND U.Storerkey = @c_Storerkey
         	            AND OD.Orderkey IS NULL)  --if any sku of the ucc not in the order
         	  OR EXISTS(SELECT 1
         	            FROM UCC U (NOLOCK)
        	            OUTER APPLY (SELECT SUM(PU.Qty) AS Qty
         	                         FROM #TMP_UCCPICK PU 
         	                         WHERE PU.UccNo = U.UccNo
         	                         AND PU.Sku = U.Sku) R
         	            WHERE U.UccNo = @c_UccNo
         	            AND U.Status < '3'       
         	            AND U.Storerkey = @c_Storerkey
         	            AND U.Sku = @c_Sku
         	            GROUP BY U.UccNo, ISNULL(R.Qty,0) 
         	            HAVING SUM(U.Qty) > @n_QtyLeftToFulfill  --if the sku of the ucc has multiple lots and exceeded order qty                   	            
         	                OR SUM(U.Qty) > ISNULL(R.Qty,0)  --if the sku of the ucc has some lots/qty excluded by the current order filtering                 
         	            )     
         	  BEGIN         	     
         	     GOTO NEXT_UCC_SINGLE
         	  END          
         	           	           	  
            IF @n_UCC_Qty <= @n_QtyLeftToFulfill
            BEGIN
               SELECT @b_success = 0
               EXECUTE   nspg_getkey
                  'PickDetailKey'
                  , 10
                  , @c_PickDetailKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         
               IF @b_debug = 1
               BEGIN
                  SELECT @c_PickDetailKey,    '',        '',                @c_OrderKey,
                         @c_OrderLineNumber,  @c_LOT,    @c_Storerkey,       @c_Sku,
                         @c_PackKey,          '6',       @n_UCC_Qty,         @n_UCC_Qty,
                         @c_Loc,              @c_ID,     '',                 'FCP',
                         '',                  '',        'N',                'U',
                         '8',                 @c_PickSlipNo
               END
               
               IF @b_success = 1
               BEGIN
                  -- select @c_Sku '@c_Sku', @c_Loc '@c_Loc', @n_UCC_Qty '@n_UCC_Qty', @c_UCCNo '@c_UCCNo'       
                  --insert pickdetail     
                  INSERT INTO PICKDETAIL ( PickDetailKey,  Caseid,        PickHeaderkey,    OrderKey,
                                           OrderLineNumber,  Lot,           Storerkey,        Sku,
                                           PackKey,          UOM,           UOMQty,           Qty,
                                           Loc,              ID,            Cartongroup,      Cartontype,
                                           DoReplenish,      replenishzone, docartonize,      Trafficcop,
                                           PickMethod,       PickSlipNo,    WaveKey)
                  VALUES (@c_PickDetailKey,       '',        '',                  @c_OrderKey,
                          @c_OrderLineNumber,     @c_LOT,    @c_Storerkey,        @c_Sku,
                          @c_PackKey,             '6',       @n_UCC_Qty,          @n_UCC_Qty,
                          @c_Loc,                 @c_ID,     RIGHT(RTRIM(@c_UCCNo),8),   'FCP',
                          '',                     '',        'N',                 'U',
                          '8',                    @c_PickSlipNo,                  @c_WaveKey)
            
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63540   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     CLOSE UCCPickCursor
                     DEALLOCATE UCCPickCursor
                     GOTO RETURN_SP
                  END
                  
                  --NJOW03 combine carton if same ucc
                  SET @c_LabelNo = ''
                  SET @c_LabelLine = ''
                  SET @n_Carton = 0
                  SELECT @c_LabelNo = LabelNo,
                         @n_Carton = CartonNo,
                         @c_LabelLine = MAX(LabelLine)
                  FROM PACKDETAIL (NOLOCK)
                  WHERE PickSlipNo = @c_Pickslipno
                  AND RefNo = @c_UCCNo
                  GROUP BY LabelNo, CartonNo                 
                  
                  IF ISNULL(@c_LabelNo,'') <> ''   --NJOW03
                  BEGIN
                     SELECT @c_Labelline = RIGHT('00000' + LTRIM(RTRIM(CAST(CAST(@c_LabelLine AS INT) + 1 AS NVARCHAR))),5)  
                  END
                  ELSE
                  BEGIN                                    
                  	 SELECT @c_LabelLine = '00001'  --NJOW03
                     -- insert packdetail                  
                     SELECT @b_success = 0
                     
                     EXECUTE nsp_GenLabelNo
                           @c_orderkey
                        ,  @c_Storerkey
                        ,  @c_LabelNo OUTPUT
                        ,  @n_Carton OUTPUT
                        ,  '2' -- treat as a "close case" transaction
                        ,  @b_success OUTPUT
                        ,  @n_err OUTPUT
                        ,  @c_errmsg OUTPUT
                  END   
            
                  IF @b_success = 1
                  BEGIN               
                     INSERT INTO PACKDETAIL (PickSlipNo, CartonNo,   LabelNo, LabelLine,  StorerKey,
                                             SKU,        Qty,        RefNo)
                     VALUES (@c_PickSlipNo,  @n_Carton,  @c_LabelNo, @c_LabelLine, @c_StorerKey,   --NJOW03
                             @c_Sku,         @n_UCC_Qty, @c_UCCNo)
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63550
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT INTO PACKDETAIL Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                        CLOSE UCCPickCursor
                        DEALLOCATE UCCPickCursor
                        GOTO RETURN_SP
                     END
                  END
                  ELSE
                     BREAK
               
                  SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT
                  SELECT @n_cnt = COUNT(*) FROM PICKDETAIL (NOLOCK) WHERE PICKDETAILKEY = @c_pickdetailkey
                  
                  IF (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                  BEGIN
                     print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                     select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
                  END
                  
                  IF NOT (@n_err = 0 AND @n_cnt = 1)
                  BEGIN
                     SELECT @b_PickInsertSuccess = 0
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                     CLOSE UCCPickCursor
                     DEALLOCATE UCCPickCursor
                     GOTO RETURN_SP
                  END
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     UPDATE UCC  WITH(ROWLOCK) --GOH01  
                        SET Status = '3',   
                           WaveKey = @c_WaveKey,   
                           OrderLineNumber = @c_OrderLineNumber,    
                           OrderKey = @c_OrderKey,   
                           PickDetailKey = @c_PickDetailKey,   
                           EditDate = GETDATE(),   
                           EditWho = SUSER_SNAME()       
                     WHERE UCCNo = @c_UCCNo    
                     AND Sku = @c_Sku  --NJOW03
            
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63570
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                        CLOSE UCCPickCursor
                        DEALLOCATE UCCPickCursor
                        GOTO RETURN_SP
                     END
            
                     EXECUTE nspg_GetKey
                         @keyname       = 'REPLENISHKEY', --Leong01
                         @fieldlength   = 10,
                         @keystring     = @c_ReplenishmentKey  OUTPUT,
                         @b_success     = @b_success   OUTPUT,
                         @n_err         = @n_err       OUTPUT,
                         @c_errmsg      = @c_errmsg    OUTPUT
               
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                     END
                     ELSE
                     BEGIN
                        INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                            StorerKey,      SKU,       FromLOC,      ToLOC,
                            Lot,            Id,        Qty,          UOM,
                            PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                            RefNo,          Confirmed, ReplenNo,     Wavekey,
                            Remark)
                        VALUES (
                            @c_ReplenishmentKey,       @c_TaskId,
                            @c_StorerKey,   @c_SKU,    @c_LOC,       'PICK',
                            @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                            @c_Packkey,     '1',       0,            0,
                            @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey, 
                            'Residual')
            
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63580   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                           CLOSE UCCPickCursor
                           DEALLOCATE UCCPickCursor
                           GOTO RETURN_SP
                        END
                     END
            
               
                     IF @n_UCC_Qty = @n_QtyLeftToFulfill
                     BEGIN
                        /*DELETE FROM WaveOrderLn WITH(ROWLOCK) --GOH01
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber*/
                        
                        --NJOW03
                        UPDATE WaveOrderLn  WITH(ROWLOCK) --GOH01  
                        SET OpenQty = 0,
                            QtyAllocated = QtyAllocated + @n_UCC_Qty
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber                        
            
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63590
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '  --NJOW03
                           CLOSE UCCPickCursor
                           DEALLOCATE UCCPickCursor
                           GOTO RETURN_SP
                        END
            
                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty
                     END -- @n_UCC_Qty = @n_QtyLeftToFulfill
                     ELSE IF @n_UCC_Qty < @n_QtyLeftToFulfill
                     BEGIN
                        UPDATE WaveOrderLn  WITH(ROWLOCK) --GOH01  
                        SET OpenQty = OpenQty - @n_UCC_Qty,
                            QtyAllocated = QtyAllocated + @n_UCC_Qty
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63600
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                           CLOSE UCCPickCursor
                           DEALLOCATE UCCPickCursor
                           GOTO RETURN_SP
                        END
            
                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty
                     END -- IF @n_UCC_Qty < @n_QtyLeftToFulfill
                  END -- @n_continue = 1 OR @n_continue = 2
               END -- @b_success = 1, Get PickDetail Key
            END -- @n_UCC_Qty <= @n_QtyLeftToFulfill
            ELSE
            BEGIN
               BREAK
            END            
   
            NEXT_UCC_SINGLE:  --NJOW03
   
            FETCH NEXT FROM UCCPickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
         END -- while  cursor
         CLOSE UCCPickCursor
         DEALLOCATE UCCPickCursor
   
         FETCH_NEXT_ORDERLINE:
            SELECT @c_PrevOrderKey = @c_OrderKey             
         
         FETCH NEXT FROM CUR_WaveDetLn INTO @c_OrderKey, @c_OrderLineNumber 
         SET @n_FetchStatus = @@FETCH_STATUS  --NJOW03 

         --NJOW03 Process multi-sku UCC. if partial allocated reverse.
         IF @n_continue IN(1,2) AND (@c_PrevOrderkey <> @c_Orderkey OR @@FETCH_STATUS = -1) 
         BEGIN
             DECLARE CUR_MULTIUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                SELECT UCC.Storerkey, UCC.UCCNo, UD.Qty, UD.QtyAllocated
                FROM ORDERS O (NOLOCK)
                JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
                JOIN UCC (NOLOCK) ON O.Storerkey = UCC.Storerkey AND PD.Pickdetailkey = UCC.Pickdetailkey
                CROSS APPLY (SELECT COUNT(DISTINCT U.Sku) AS NoofSku, 
                                    SUM(U.Qty) AS Qty,
                                    SUM(CASE WHEN U.Status >= '3' THEN U.Qty ELSE 0 END) AS QtyAllocated
                             FROM UCC U(NOLOCK) 
                             WHERE U.UCCNo = UCC.UCCNo 
                             AND U.Storerkey = UCC.Storerkey
                             HAVING COUNT(DISTINCT U.Sku) > 1) UD
                WHERE O.Orderkey = @c_PrevOrderkey
                AND UCC.Wavekey = @c_Wavekey
                AND UCC.Status = '3'
                AND PD.CartonType = 'FCP'          
               	AND UD.Qty <> UD.QtyAllocated
                GROUP BY UCC.Storerkey, UCC.UCCNo, UD.Qty, UD.QtyAllocated
                ORDER BY UCC.UccNo

             OPEN CUR_MULTIUCC
             
             FETCH NEXT FROM CUR_MULTIUCC INTO @c_Storerkey, @c_UCCNo, @n_UCCQty, @n_UCCQtyAllocated

             WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
             BEGIN
             	  IF @n_UCCQty <> @n_UCCQtyAllocated  --partiall allocated UCC
             	  BEGIN
             	  	 --Reverse WaveOrderLn
             	  	 DECLARE CUR_ORDLN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             	  	    SELECT PICKDETAIL.OrderLineNumber, PICKDETAIL.Qty
                	    FROM PICKDETAIL (NOLOCK)
                	  	JOIN UCC (NOLOCK) ON PICKDETAIL.Pickdetailkey = UCC.Pickdetailkey 
                	  	                     AND PICKDETAIL.Orderkey = UCC.Orderkey
                	  	                     AND PICKDETAIL.OrderLineNumber = UCC.OrderLineNumber                	  	                     
                	  	WHERE UCC.UCCNo = @c_UCCNo
             	     	  AND UCC.Wavekey = @c_Wavekey             	  	 
             	     	  AND UCC.Storerkey = @c_Storerkey
             	  	    AND PICKDETAIL.Orderkey = @c_PrevOrderKey
             	  	    
                   OPEN CUR_ORDLN
                   
                   FETCH NEXT FROM CUR_ORDLN INTO @c_OrderLineNumber_rev, @n_Qty_rev
             	  	    
                   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
                   BEGIN                   	
                      UPDATE WaveOrderLn WITH (ROWLOCK) 
                      SET OpenQty = OpenQty + @n_Qty_rev ,
                          QtyAllocated = QtyAllocated - @n_Qty_rev
                      WHERE OrderKey = @c_PrevOrderKey
                      AND   OrderLineNumber = @c_OrderLineNumber_Rev                           	  
                      
                      SELECT @n_err = @@ERROR
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue=3
                         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63610
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                      END                                 

                      FETCH NEXT FROM CUR_ORDLN INTO @c_OrderLineNumber_rev, @n_Qty_rev                      
                   END
                   CLOSE CUR_ORDLN
                   DEALLOCATE CUR_ORDLN
             	  	                 	  	                 	  	              	  	              	  	 
             	  	 --Reverse Pickdetail
             	  	 DELETE PICKDETAIL 
             	  	 FROM PICKDETAIL (NOLOCK)
             	  	 JOIN UCC (NOLOCK) ON PICKDETAIL.Pickdetailkey = UCC.Pickdetailkey 
             	  	                      AND PICKDETAIL.Orderkey = UCC.Orderkey
             	  	                      AND PICKDETAIL.OrderLineNumber = UCC.OrderLineNumber
             	  	 WHERE UCC.UCCNo = @c_UCCNo
             	  	 AND UCC.Wavekey = @c_Wavekey 
                   AND UCC.Storerkey = @c_Storerkey             	  	             	  	 
             	  	 AND PICKDETAIL.Orderkey = @c_PrevOrderKey

                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue=3
                      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63620
                      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Pickdetail Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                   END
             	  	              	  	 
             	  	 --Reverse UCC
             	  	 UPDATE UCC WITH (ROWLOCK)
             	  	 SET Status = '2',
             	  	     Wavekey = '',
             	  	     Orderkey = '',
             	  	     OrderLineNumber = '',
             	  	     Pickdetailkey = ''             	  	     
             	  	 WHERE UCCNo = @c_UCCNo
             	  	 AND UCC.Storerkey = @c_Storerkey
             	  	 AND UCC.Wavekey = @c_Wavekey
             	  	 AND UCC.Orderkey = @c_PrevOrderKey
             	  	 AND UCC.Status = '3'
             	  	 
                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue=3
                      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63630
                      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCCC Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                   END             	  	 
             	  	 
             	  	 --Reverse Replenishment
             	  	 DELETE REPLENISHMENT
             	  	 WHERE Storerkey = @c_Storerkey
             	  	 AND RefNo = @c_UCCNo
             	  	 AND ReplenishmentGroup = @c_TaskId
             	  	 AND Wavekey = @c_Wavekey
             	  	 AND ToLoc = 'PICK'
             	  	 
                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue=3
                      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63640
                      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Replenishment Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                   END
             	  	              	  	 
             	  	 --Revsese Packdetail
             	  	 SET @n_UCCCartonNo = 0
             	  	 SELECT TOP 1 @n_UCCCartonNo = CartonNo
             	  	 FROM PACKDETAIL (NOLOCK)
             	  	 WHERE PickslipNo = @c_PickSlipNo
             	  	 AND RefNo = @c_UCCNo            
             	  	 
             	  	 IF ISNULL(@n_UCCCartonNo,0) > 0
             	  	 BEGIN             	  	              	  	 
             	  	    DELETE FROM PACKDETAIL
             	  	    WHERE PickslipNo = @c_PickSlipNo
             	  	    AND RefNo = @c_UCCNo             	  	 

                      SELECT @n_err = @@ERROR
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue=3
                         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63650
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Packdetail Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                      END
             	  	    
             	  	    UPDATE PACKDETAIL WITH (ROWLOCK)  --Re-arrange carton no
             	  	    SET CartonNo = CartonNo - 1
             	  	    WHERE PickslipNo = @c_PickSlipNo
             	  	    AND CartonNo > @n_UCCCartonNo
             	  	    
                      SELECT @n_err = @@ERROR
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue=3
                         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63660
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Packdetail Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                      END             	  	    
             	  	 END
             	  	              	  	              	  	              	  	              	  	 
             	  	 --Delete zero qty line
             	  	 DELETE FROM WaveOrderLn
                   WHERE OrderKey = @c_PrevOrderKey
                   AND OrderLineNumber = @c_OrderLineNumber_Rev       
                   AND OpenQty <= 0
             	  END           
             	
                FETCH NEXT FROM CUR_MULTIUCC INTO @c_Storerkey, @c_UCCNo, @n_UCCQty, @n_UCCQtyAllocated
             END  
             CLOSE CUR_MULTIUCC                      	   
             DEALLOCATE CUR_MULTIUCC
         END
      END -- While 2      
      CLOSE CUR_WaveDetLn
      DEALLOCATE CUR_WaveDetLn   
      --SELECT @c_PrevOrderKey = @c_OrderKey         
   
      IF @b_debug = 1
      BEGIN
         Print 'End Allocate Full Carton (UCC)..'
         PRint ''
         Print 'Start Dynamic Pick Face Replenishment...'
      END
   END
   
   --tlting01
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      
      BEGIN TRAN
   END

   -- Dynamic Pick Face Replenishment
   -- Generate conso ucc replenishment from bulk to dynamicpk (dynamic pick loc). By sku.putawayzone
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @n_PickSeq int
      IF EXISTS(SELECT 1 FROM WaveOrderLn (NOLOCK) WHERE  WaveKey = @c_WaveKey and OpenQty > 0 )
      BEGIN
         CREATE TABLE #TempDynamicPick
         (PickSeq      smallint IDENTITY(1,1) PRIMARY KEY,
          PutawayZone  NVARCHAR(10),
          StorerKey    NVARCHAR(15),
          SKU          NVARCHAR(20),
          Lottable01   NVARCHAR(18),
          Lottable02   NVARCHAR(18),
          Lottable03   NVARCHAR(18),
          Lottable06   NVARCHAR(30),  
          Lottable07   NVARCHAR(30),  
          Lottable08   NVARCHAR(30),  
          Lottable09   NVARCHAR(30),  
          Lottable10   NVARCHAR(30),  
          Lottable11   NVARCHAR(30),  
          Lottable12   NVARCHAR(30),         
          Qty          int,
          Status       NVARCHAR(10),  --NJOW01
          C_Country    NVARCHAR(30) NULL,  --NJOW01
          OrderGroup   NVARCHAR(20))  --NJOW02
   
         CREATE TABLE #TempDynamicLoc
            (Rowref       INT IDENTITY(1,1) PRIMARY KEY,
             PutawayZone  NVARCHAR(10),
             LOC          NVARCHAR(10),
             LogicalLoc   NVARCHAR(18),
             Status       NVARCHAR(5),
             StorerKey    NVARCHAR(15), 
             SKU          NVARCHAR(20), 
             Lottable01   NVARCHAR(18), 
             Lottable02   NVARCHAR(18),
             Lottable03   NVARCHAR(18))
             
         --NJOW03     
         CREATE TABLE #TMP_ORDERLINEUCC 
            (Rowref          INT IDENTITY(1,1) PRIMARY KEY,            
             Orderkey        NVARCHAR(10), 
             OrderLineNumber NVARCHAR(5), 
             UCCNo           NVARCHAR(20),
             Qty             INT)         
         CREATE INDEX IDX_OLUUCC ON #TMP_ORDERLINEUCC (UCCNo)                                       
   
         INSERT INTO #TempDynamicPick (PutawayZone, StorerKey, SKU, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07,   
                     Lottable08, Lottable09, Lottable10, Lottable11, Lottable12,  Qty, STATUS, c_country, OrderGroup)  --NJOW02
         SELECT SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU,    
                WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03, WaveOrderLn.Lottable06, WaveOrderLn.Lottable07,   
                WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12,       
                SUM(WaveOrderLn.OpenQty) as Qty,
                WaveOrderLn.Status, CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.c_Country ELSE '' END, --NJOW01
                CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.OrderGroup ELSE '' END  --NJOW02             
         FROM  WaveOrderLn (NOLOCK)
         JOIN ORDERS (NOLOCK) ON WaveOrderLn.Orderkey = ORDERS.Orderkey --NJOW01
         JOIN  SKU (NOLOCK) ON (WaveOrderLn.StorerKey = SKu.StorerKey and WaveOrderLn.SKU = SKU.SKU)
         WHERE WaveOrderLn.WaveKey = @c_WaveKey and WaveOrderLn.OpenQty > 0
         GROUP BY SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03,
                  WaveOrderLn.Lottable06, WaveOrderLn.Lottable07,  
                  WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12,
                  WaveOrderLn.Status, CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.c_Country ELSE '' END, --NJOW01    
                  CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.OrderGroup ELSE '' END --NJOW02                  
         ORDER BY SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU
   
         SET @c_DynamicLocLoop = '0'
         SET @c_PrevPutAwayZone = ''
   
         INSERT INTO #TempDynamicLoc (PutawayZone, LOC, LogicalLoc, STATUS, StorerKey, SKU, Lottable01,
                     Lottable02, Lottable03)
         SELECT DISTINCT LOC.PutawayZone, LOC.LOC, LOC.LogicalLocation, '0', 
                StorerKey='', SKU='', Lottable01='', Lottable02='', Lottable03='' 
         FROM   LOC (NOLOCK)
         WHERE EXISTS(SELECT 1 FROM WaveOrderLn WITH (NOLOCK)                  
                      JOIN   SKU (NOLOCK) ON (WaveOrderLn.StorerKey = SKu.StorerKey and WaveOrderLn.SKU = SKU.SKU)                  
                      WHERE  WaveKey = @c_WaveKey and OpenQty > 0
                      AND  LOC.PutawayZone = SKU.PutawayZone)
         AND    LOC.LocationType = 'DYNAMICPK'
         AND    LOC.LocationFlag <> 'HOLD'
         ORDER BY LOC.Loc                  
   
         -- Added to consider non confirm replenishment 
   --      UPDATE TDL 
   --         SET TDL.StorerKey = R.StorerKey, TDL.SKU = R.SKU, TDL.Lottable01 = LA.Lottable01, 
   --             TDL.Lottable02 = LA.Lottable02, TDL.Lottable03 = LA.Lottable03 
   --      FROM #TempDynamicLoc TDL
   --      JOIN REPLENISHMENT R WITH (NOLOCK) ON R.ToLoc = TDL.LOC 
   --      JOIN LOTATTRIBUTE AS LA (NOLOCK) ON LA.Lot = R.Lot   
   --      WHERE R.Confirmed = 'N'
         
         IF @b_debug = 1
         BEGIN
            SELECT TDL.*, LOC.NoMixLottable01,LOC.NoMixLottable02,LOC.NoMixLottable03 
            FROM #TempDynamicLoc TDL
            JOIN LOC WITH (NOLOCK) ON LOC.LOC = TDL.LOC 
         END
         
         IF EXISTS(SELECT 1 FROM #TempDynamicPick)
         BEGIN
            SELECT @n_PickSeq = 0
   
            WHILE 1=1 and (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @n_PickSeq = MIN(PickSeq)
               FROM   #TempDynamicPick
               WHERE  PickSeq > @n_PickSeq
   
               IF @n_PickSeq IS NULL OR @n_PickSeq = 0
                  BREAK
   
               SELECT @c_StorerKey  = SKU.StorerKey,
                      @c_SKU        = SKU.SKU,
                      @c_Lottable01 = #TempDynamicPick.Lottable01,
                      @c_Lottable02 = #TempDynamicPick.Lottable02,
                      @c_Lottable03 = #TempDynamicPick.Lottable03,
                      @c_Lottable06 = #TempDynamicPick.Lottable06,  
                      @c_Lottable07 = #TempDynamicPick.Lottable07,  
                      @c_Lottable08 = #TempDynamicPick.Lottable08,  
                      @c_Lottable09 = #TempDynamicPick.Lottable09,  
                      @c_Lottable10 = #TempDynamicPick.Lottable10,  
                      @c_Lottable11 = #TempDynamicPick.Lottable11,  
                      @c_Lottable12 = #TempDynamicPick.Lottable12,  
                      @n_OpenQty    = #TempDynamicPick.Qty,    
                      @c_Lottable01Label = SKU.Lottable01Label,    
                      @c_Lottable02Label = SKU.Lottable02Label,    
                      @c_Lottable03Label = SKU.Lottable03Label,    
                      @c_Lottable04Label = SKU.Lottable04Label,    
                      @c_Lottable05Label = SKU.Lottable05Label,
                      @c_Lottable06Label = SKU.Lottable06Label,   
                      @c_Lottable07Label = SKU.Lottable07Label,   
                      @c_Lottable08Label = SKU.Lottable08Label,   
                      @c_Lottable09Label = SKU.Lottable09Label,   
                      @c_Lottable10Label = SKU.Lottable10Label,   
                      @c_Lottable11Label = SKU.Lottable11Label,   
                      @c_Lottable12Label = SKU.Lottable12Label,   
                      @c_Lottable13Label = SKU.Lottable13Label,   
                      @c_Lottable14Label = SKU.Lottable14Label,   
                      @c_Lottable15Label = SKU.Lottable15Label,   
                      @c_PutawayZone     = SKU.PutawayZone,
                      @c_Packkey = SKU.Packkey,
                      @c_UOM = PACK.PackUOM3,
                      @c_Status = #TempDynamicPick.Status, --NJOW01
                      @c_c_Country = #TempDynamicPick.C_country, --NJOW01
                      @c_OrderGroup = #TempDynamicPick.OrderGroup --NJOW02                     
               FROM #TempDynamicPick
               JOIN SKU (NOLOCK) ON (SKU.StorerKey = #TempDynamicPick.StorerKey AND SKU.SKU = #TempDynamicPick.SKU)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               WHERE #TempDynamicPick.PickSeq = @n_PickSeq
   
               IF @c_PrevPutAwayZone <> @c_PutawayZone
               BEGIN
                  SET @c_DynamicLocLoop = '0'
                  SET @c_PrevPutAwayZone = @c_PutawayZone
               END
   
               TRUNCATE TABLE #TMP_UCCPICK --NJOW03
   
               SELECT @c_ExecStatement =
                  --'DECLARE DynPickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
                  'INSERT INTO #TMP_UCCPICK (UCCNo, Lot, Sku, Loc, ID, Qty) ' +  --NJOW03                  
                  'SELECT UCC.UCCNo, UCC.Lot, UCC.Sku, UCC.Loc, UCC.ID, UCC.Qty ' +
                  'FROM UCC (NOLOCK) ' +
                  'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
                  'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
                  'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
                  'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
                  'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
                  'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
                  'OUTER APPLY (SELECT TOP 1 R.Replenishmentkey
                                FROM REPLENISHMENT R (NOLOCK) 
                                WHERE R.RefNo = UCC.UCCNo 
                                AND R.Storerkey = UCC.Storerkey
                                AND R.Wavekey = @c_Wavekey
                                AND R.ReplenishmentGroup = @c_TaskID
                                AND R.Confirmed = ''N''
                                AND R.Toloc = @c_MultiUCCToLoc
                                AND R.Remark = ''Dynamic Pick Loc'') REPUCC ' +  --NJOW03                              
                  'WHERE UCC.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  'AND   UCC.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  'AND   UCC.Status BETWEEN ''1'' AND ''4'' ' +
                  'AND   UCC.Status <> ''3'' ' +
                  'AND   UCC.Qty <= ' + RTRIM(CAST(@n_OpenQty as NVARCHAR(10))) + ' ' +
                  'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
                  'AND   LOC.LocationType = ''OTHER'' ' +
                  'AND   LOC.LocationFlag <> ''HOLD'' ' +
                  'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
                  'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '
   
               IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                     ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
               END
   
               IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '  
     
               IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''  
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '  
   
               IF @c_Status = 'F'
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND ' + RTRIM(@c_Filter_Notes) + ' '  
               
   --            IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
   --            BEGIN
   --               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
   --                  ' ORDER By LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
   --            END
   --            ELSE
               BEGIN
               	  IF ISNULL(@c_Sort_Notes2,'') <> ''  --NJOW01
               	     SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' ORDER BY CASE WHEN REPUCC.Replenishmentkey IS NOT NULL THEN 1 ELSE 2 END, ' + RTRIM(@c_Sort_Notes2)  --NJOW03
               	  ELSE   
                      SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                        ' ORDER By CASE WHEN REPUCC.Replenishmentkey IS NOT NULL THEN 1 ELSE 2 END, LotAttribute.Lottable05, LotAttribute.lot, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '  --NJOW03                                         
               END
   
               --EXEC sp_executesql @c_ExecStatement
               EXEC sp_executesql @c_ExecStatement,   --NJOW01
                  N'@c_c_Country NVARCHAR(30), @c_OrderGroup NVARCHAR(20), @c_Wavekey NVARCHAR(10), @c_TaskID NVARCHAR(10), @c_MultiUCCToLoc NVARCHAR(10)',  --NJOW02 NJOW03
                  @c_c_Country,
                  @c_OrderGroup, --NJOW02            
                  @c_Wavekey,  --NJOW03
                  @c_TaskId,   --NJOW03
                  @c_MultiUCCToLoc  --NJOW03
      
               DECLARE DynPickCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    --NJOW03
                  SELECT UCCNo, Lot, Loc, ID, Qty
                  FROM #TMP_UCCPICK
                  ORDER BY RowID
               
               OPEN DynPickCursor
               
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err = 16905
               BEGIN
                  CLOSE DynPickCursor
                  DEALLOCATE DynPickCursor
               END
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63670   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  GOTO RETURN_SP
               END
               ELSE
               BEGIN
                  SELECT @n_CursorOpen = 1
               END
   
               SELECT @n_QtyLeftToFulfill = @n_OpenQty
   
               FETCH NEXT FROM DynPickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
   
               WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
               BEGIN
               	  --NJOW03 if any sku of the ucc not in the orders of same lottable group
      	          IF EXISTS(SELECT 1
         	                  FROM UCC U (NOLOCK)
         	                  OUTER APPLY (SELECT SUM(OD.OpenQty) OpenQty
         	                               FROM  WaveOrderLn OD (NOLOCK) 
         	                               WHERE OD.Storerkey = U.Storerkey 
         	                               AND OD.Sku = U.Sku          	                                    	                                               
         	                               AND OD.Wavekey = @c_Wavekey
                                         --AND OD.Lottable01 = @c_Lottable01 
                                         --AND OD.Lottable02 = @c_Lottable02 
                                         --AND OD.Lottable03 = @c_Lottable03 
                                         --AND OD.Lottable06 = @c_Lottable06 
                                         --AND OD.Lottable07 = @c_Lottable07 
                                         --AND OD.Lottable08 = @c_Lottable08 
                                         --AND OD.Lottable09 = @c_Lottable09 
                                         --AND OD.Lottable10 = @c_Lottable10 
                                         --AND OD.Lottable11 = @c_Lottable11 
                                         --AND OD.Lottable12 = @c_Lottable12
                                         ) OL
         	                  WHERE U.UCCNo = @c_UCCNo
         	                  AND U.Status < '3'
         	                  AND U.Storerkey = @c_Storerkey
         	                  AND (OL.OpenQty IS NULL OR OL.OpenQty < U.Qty) 
         	                  )
         	        OR EXISTS(SELECT 1
         	                  FROM UCC U (NOLOCK)
        	                  OUTER APPLY (SELECT SUM(PU.Qty) AS Qty
         	                               FROM #TMP_UCCPICK PU 
         	                               WHERE PU.UccNo = U.UccNo
         	                               AND PU.Sku = U.Sku) R
         	                  WHERE U.UccNo = @c_UccNo
         	                  AND U.Status < '3'       
         	                  AND U.Storerkey = @c_Storerkey
         	                  AND U.Sku = @c_Sku
         	                  GROUP BY U.UccNo, ISNULL(R.Qty,0) 
         	                  HAVING SUM(U.Qty) > @n_QtyLeftToFulfill  --if the sku of the ucc has multiple lots and exceeded wave qty                   	            
         	                      OR SUM(U.Qty) > ISNULL(R.Qty,0)  --if the sku of the ucc has some lots/qty excluded by the current wave filtering                 
         	                 )              	                  
         	        BEGIN
         	           GOTO NEXT_UCC_CONSO
         	        END    
               	  
                  IF @n_UCC_Qty <= @n_QtyLeftToFulfill
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_QtyLeftToFulfill '@n_QtyLeftToFulfill', @c_DynamicLocLoop '@c_DynamicLocLoop'
                     END
   
                     UPDATE UCC WITH(ROWLOCK) --GOH01  
                        SET Status = '3',   
                           WaveKey = @c_WaveKey,   
                           EditDate = GETDATE(),   
                           EditWho = SUSER_SNAME()    
                     WHERE UCCNo = @c_UCCNo    
                     AND Storerkey = @c_Storerkey  --NJOW03
                     AND Sku = @c_Sku  --NJOW03
                     
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63680
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                        CLOSE DynPickCursor
                        DEALLOCATE DynPickCursor
                        GOTO RETURN_SP
                     END
   
                     EXECUTE nspg_GetKey
                         @keyname       = 'REPLENISHKEY',  
                         @fieldlength   = 10,
                         @keystring     = @c_ReplenishmentKey  OUTPUT,
                         @b_success     = @b_success   OUTPUT,
                         @n_err         = @n_err       OUTPUT,
                         @c_errmsg      = @c_errmsg    OUTPUT
   
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        CLOSE DynPickCursor
                        DEALLOCATE DynPickCursor
                        GOTO RETURN_SP
                     END
                     ELSE
                     BEGIN
                        SET @c_ToLoc = ''
                        SET @b_NewLocation = 0
                        
                        --NJOW03
                     	  IF EXISTS(SELECT 1
                     	            FROM UCC (NOLOCK)
                     	            WHERE Storerkey = @c_Storerkey
                     	            AND UCCNo = @c_UCCNo
                     	            HAVING COUNT(DISTINCT Sku) > 1)
                     	  BEGIN
                     	     SELECT @c_Toloc = @c_MultiUCCToLoc
                     	  END
                     	                                 	  
                        -- Search is there any SKU already assigned
                        IF ISNULL(RTRIM(@c_ToLOC),'') = ''    --NJOW03
                        BEGIN
                           SELECT TOP 1 @c_ToLOC = TDL.LOC
                           FROM   #TempDynamicLoc TDL 
                           JOIN LOC WITH (NOLOCK) ON LOC.LOC = TDL.LOC 
                           WHERE  TDL.PutawayZone = @c_PutawayZone
                           AND    TDL.Status = @c_DynamicLocLoop 
                           AND    TDL.StorerKey = @c_StorerKey 
                           AND    TDL.SKU = @c_Sku
                           AND    TDL.Lottable01 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable01 ELSE TDL.Lottable01 END
                           AND    TDL.Lottable02 = CASE WHEN ISNULL(LOC.NoMixLottable02,'0') = '1' THEN @c_Lottable02 ELSE TDL.Lottable02 END 
                           AND    TDL.Lottable03 = CASE WHEN ISNULL(LOC.NoMixLottable03,'0') = '1' THEN @c_Lottable03 ELSE TDL.Lottable03 END  
                           ORDER BY TDL.LogicalLoc, TDL.LOC
                        END
                        
                        IF @b_debug = 1 AND ISNULL(RTRIM(@c_ToLOC),'') = ''
                        BEGIN
                           PRINT 'No Match Location Found'
                           PRINT '-----------------------'
                           PRINT 'SKU: ' + @c_Sku
                           PRINT 'LOTTABLE 01: ' + @c_Lottable01  
                           PRINT 'LOTTABLE 02: ' + @c_Lottable02
                           PRINT 'LOTTABLE 03: ' + @c_Lottable03
                           PRINT '@c_PutawayZone: ' + @c_PutawayZone
                        END             
                                   
                        IF ISNULL(RTRIM(@c_ToLOC),'') = ''
                        BEGIN                     
                           SELECT TOP 1 @c_ToLOC = LOC
                           FROM   #TempDynamicLoc
                           WHERE  PutawayZone = @c_PutawayZone
                           AND    [Status] = @c_DynamicLocLoop
                           AND    StorerKey = ''
                           AND    SKU = ''
                           AND    Lottable01 = ''
                           AND    Lottable02 = ''
                           AND    Lottable03 = ''
                           ORDER BY LogicalLoc, LOC
                           
                           IF ISNULL(RTRIM(@c_ToLOC),'') <> ''
                              SET @b_NewLocation = 1
                        END 
   
                        IF ISNULL(RTRIM(@c_ToLOC),'') = ''
                        BEGIN
                           SELECT @c_DynamicLocLoop = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(5) )
                           
                           SELECT TOP 1 @c_ToLOC = TDL.LOC
                           FROM   #TempDynamicLoc TDL 
                             JOIN LOC WITH (NOLOCK) ON LOC.LOC = TDL.LOC 
                           WHERE  TDL.PutawayZone = @c_PutawayZone
                           AND    TDL.Status = @c_DynamicLocLoop 
                           AND    TDL.StorerKey = @c_StorerKey 
                           AND    TDL.SKU = @c_Sku
                           AND    TDL.Lottable01 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable01 ELSE TDL.Lottable01 END
                           AND    TDL.Lottable02 = CASE WHEN ISNULL(LOC.NoMixLottable02,'0') = '1' THEN @c_Lottable02 ELSE TDL.Lottable02 END 
                           AND    TDL.Lottable03 = CASE WHEN ISNULL(LOC.NoMixLottable03,'0') = '1' THEN @c_Lottable03 ELSE TDL.Lottable03 END  
                           ORDER BY TDL.LogicalLoc, TDL.LOC
                        END
   
                        IF ISNULL(RTRIM(@c_ToLOC),'') = ''
                        BEGIN
                           --SELECT @c_DynamicLocLoop = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(5) )
   
                           SELECT TOP 1 @c_ToLOC = LOC
                           FROM   #TempDynamicLoc
                           WHERE  PutawayZone = @c_PutawayZone
                           AND    [Status] = @c_DynamicLocLoop
                           AND    StorerKey = ''
                           AND    SKU = ''
                           AND    Lottable01 = ''
                           AND    Lottable02 = ''
                           AND    Lottable03 = ''
                           ORDER BY LogicalLoc, LOC
   
                           IF ISNULL(RTRIM(@c_ToLOC),'') <> ''
                              SET @b_NewLocation = 1                        
                        END
                        
                        IF ISNULL(RTRIM(@c_ToLOC),'') = ''
                        BEGIN
                           --SELECT @c_DynamicLocLoop = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(5) )
                           
                           SELECT TOP 1 @c_ToLOC = TDL.LOC
                           FROM   #TempDynamicLoc TDL 
                           JOIN LOC WITH (NOLOCK) ON LOC.LOC = TDL.LOC 
                           WHERE  TDL.PutawayZone = @c_PutawayZone
                           AND    TDL.Status = @c_DynamicLocLoop 
                           AND    TDL.Storerkey = @c_Storerkey
                           AND    LOC.Comminglelot = '1'
                           AND    LOC.comminglesku = '1'
                           AND    ISNULL(LOC.NoMixLottable01,'0') <> '1'
                           AND    ISNULL(LOC.NoMixLottable02,'0') <> '1'
                           AND    ISNULL(LOC.NoMixLottable03,'0') <> '1'
                           ORDER BY TDL.LogicalLoc, TDL.LOC
   
                           IF ISNULL(RTRIM(@c_ToLOC),'') = ''
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = '', @n_err = 63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Dynamic Pick Location(DYNAMICPK) Not Found or FULL! Sku: ' + RTRIM(@c_sku) + ' Putawayzone: ' + RTRIM(@c_Putawayzone) + '. (ispWRUCC02)' --NJOW03
                              CLOSE DynPickCursor
                              DEALLOCATE DynPickCursor
                              GOTO RETURN_SP
                           END
                        END   
   
                        IF @n_continue=1 OR @n_continue=2
                        BEGIN
                           INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                               StorerKey,      SKU,       FromLOC,      ToLOC,
                               Lot,            Id,        Qty,          UOM,
                               PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                               RefNo,          Confirmed, ReplenNo,     Wavekey,
                               Remark)
                           VALUES (
                               @c_ReplenishmentKey,       @c_TaskId,
                               @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                               @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                               @c_Packkey,     '1',       0,            0,
                               @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey,
                               'Dynamic Pick Loc')
   
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63690   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                              CLOSE DynPickCursor
                              DEALLOCATE DynPickCursor
                              GOTO RETURN_SP
   
                           END
                           ELSE IF @c_Toloc <> @c_MultiUCCToLoc  --NJOW03  multi-ucc no dynamic loc
                           BEGIN
                              IF @b_NewLocation = 1
                              BEGIN
                                 UPDATE TDL
                                   SET Status = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(5) ), 
                                       StorerKey = @c_StorerKey,
                                       SKU = @c_Sku,
                                       Lottable01 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable01 ELSE '' END, 
                                       Lottable02 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable02 ELSE '' END,
                                       Lottable03 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable03 ELSE '' END
                                 FROM #TempDynamicLoc TDL 
                                 JOIN LOC WITH (NOLOCK) ON TDL.LOC = LOC.LOC 
                                 WHERE TDL.PutawayZone = @c_PutawayZone
                                 AND   TDL.LOC = @c_ToLOC                              
                              END
                              ELSE
                              BEGIN
                                 UPDATE #TempDynamicLoc
                                   SET Status = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(5) ) 
                                 WHERE PutawayZone = @c_PutawayZone
                                 AND   LOC = @c_ToLOC                              
                              END
                              
                           END
                        END
                     END -- IF NOT @b_success = 1 (GetKey) ReplenishmentKey
   
                     IF @n_continue=1 OR @n_continue=2
                     BEGIN
                     	  --NJOW03 S
                        SELECT @c_OrderKey = ''
                        SELECT @n_UCC_Qty2 = @n_UCC_Qty
                        
                        WHILE 1=1 AND @n_Ucc_Qty2 > 0
                        BEGIN
                           SELECT @c_OrderKey = MIN(OrderKey)
                           FROM   WaveOrderLn (NOLOCK)
                           WHERE  WaveKey = @c_WaveKey
                           AND    OrderKey > @c_OrderKey
                           AND    StorerKey = @c_StorerKey
                           AND    Lottable01 = @c_Lottable01
                           AND    Lottable02 = @c_Lottable02
                           AND    Lottable03 = @c_Lottable03
                           AND    Lottable06 = @c_Lottable06
                           AND    Lottable07 = @c_Lottable07
                           AND    Lottable08 = @c_Lottable08
                           AND    Lottable09 = @c_Lottable09
                           AND    Lottable10 = @c_Lottable10
                           AND    Lottable11 = @c_Lottable11
                           AND    Lottable12 = @c_Lottable12
                           AND    SKU = @c_SKU
                        
                           IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = ''
                              BREAK
                        
                           SELECT @c_OrderLineNumber = ''
                        
                           WHILE 1=1 AND @n_UCC_Qty2 > 0
                           BEGIN
                              SELECT @c_OrderLineNumber = MIN(OrderLineNumber)
                              FROM   WaveOrderLn (NOLOCK)
                              WHERE  WaveKey = @c_WaveKey
                              AND    StorerKey = @c_StorerKey
                              AND    SKU = @c_SKU
                              AND    Lottable01 = @c_Lottable01
                              AND    Lottable02 = @c_Lottable02
                              AND    Lottable03 = @c_Lottable03
                              AND    Lottable06 = @c_Lottable06
                              AND    Lottable07 = @c_Lottable07
                              AND    Lottable08 = @c_Lottable08
                              AND    Lottable09 = @c_Lottable09
                              AND    Lottable10 = @c_Lottable10
                              AND    Lottable11 = @c_Lottable11
                              AND    Lottable12 = @c_Lottable12
                              AND    OrderKey = @c_OrderKey
                              AND    OrderLineNumber > @c_OrderLineNumber
                              AND    OpenQty > 0
                        
                              IF dbo.fnc_RTrim(@c_OrderLineNumber) IS NULL OR dbo.fnc_RTrim(@c_OrderLineNumber) = ''
                                 BREAK                        
                        
                              SELECT @n_OpenQty2 = OpenQty
                              FROM WaveOrderLn (NOLOCK)
                              WHERE OrderKey = @c_OrderKey
                              AND   OrderLineNumber = @c_OrderLineNumber
                        
                              IF (@n_UCC_Qty2 > @n_OpenQty2) OR (@n_UCC_Qty2 = @n_OpenQty2)
                              BEGIN
                        			   UPDATE WaveOrderLn
                        			   SET OpenQty = 0,
                        			       QtyAllocated = QtyAllocated + @n_OpenQty2
                        	       WHERE OrderKey = @c_OrderKey
                        	       AND   OrderLineNumber = @c_OrderLineNumber
                        	       
                        	       IF @c_Toloc = @c_MultiUCCToLoc  --insert multi-sku UCC for reverse later
                        	       BEGIN
                        	          INSERT INTO #TMP_ORDERLINEUCC (Orderkey, OrderLineNumber, UCCNo, Qty)
                        	          VALUES (@c_Orderkey, @c_OrderLineNumber, @c_UCCNo, @n_OpenQty2)
                        	       END
                                                 
                                 SELECT @n_UCC_Qty2 = @n_UCC_Qty2 - @n_OpenQty2
                              END
                        		  ELSE
                              BEGIN
                        			   UPDATE WaveOrderLn
                                 SET OpenQty = OpenQty - @n_UCC_Qty2,
                                     QtyAllocated = QtyAllocated + @n_UCC_Qty2
                                 WHERE OrderKey = @c_OrderKey
                                 AND   OrderLineNumber = @c_OrderLineNumber
                        	       
                        	       IF @c_Toloc = @c_MultiUCCToLoc 
                        	       BEGIN
                        	          INSERT INTO #TMP_ORDERLINEUCC (Orderkey, OrderLineNumber, UCCNo, Qty)
                        	          VALUES (@c_Orderkey, @c_OrderLineNumber, @c_UCCNo, @n_UCC_Qty2)
                        	       END
                                                
                                 SELECT @n_UCC_Qty2 = 0
                              END
                           END -- while order line
                        END -- while orderkey                     	  
                     	  --NJOW03 E
                     	  
                        IF @n_UCC_Qty = @n_QtyLeftToFulfill
                        BEGIN
                           DELETE FROM #TempDynamicPick
                           WHERE #TempDynamicPick.PickSeq = @n_PickSeq
                              
                           --EXEC ispAllocateWaveOrderLn @c_WaveKey, @c_StorerKey, @c_SKU,
                           --@c_Lottable01, @c_Lottable02, @c_Lottable03, @n_UCC_Qty
   
                           /*  --NJOW03 Removed
                             EXEC ispAllocateWaveOrderLn
                              @c_WaveKey = @c_WaveKey,
                              @c_StorerKey = @c_StorerKey,
                              @c_SKU = @c_SKU,
                              @c_Lottable01 = @c_Lottable01,
                              @c_Lottable02 = @c_Lottable02,
                              @c_Lottable03 = @c_Lottable03,
                              @c_Lottable06 = @c_Lottable06,
                              @c_Lottable07 = @c_Lottable07,
                              @c_Lottable08 = @c_Lottable08,
                              @c_Lottable09 = @c_Lottable09,
                              @c_Lottable10 = @c_Lottable10,
                              @c_Lottable11 = @c_Lottable11,
                              @c_Lottable12 = @c_Lottable12,
                              @n_UCC_Qty = @n_UCC_Qty
                           */                             
   
                           BREAK
                        END -- @n_UCC_Qty = @n_QtyLeftToFulfill
                        ELSE IF @n_UCC_Qty < @n_QtyLeftToFulfill
                        BEGIN
                           UPDATE #TempDynamicPick
                              SET #TempDynamicPick.Qty = #TempDynamicPick.Qty - @n_UCC_Qty
                           WHERE #TempDynamicPick.PickSeq = @n_PickSeq
   
                           SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty
   
                           /* --NJOW03 Removed
                            EXEC ispAllocateWaveOrderLn
                              @c_WaveKey = @c_WaveKey,
                              @c_StorerKey = @c_StorerKey,
                              @c_SKU = @c_SKU,
                              @c_Lottable01 = @c_Lottable01,
                              @c_Lottable02 = @c_Lottable02,
                              @c_Lottable03 = @c_Lottable03,
                              @c_Lottable06 = @c_Lottable06,
                              @c_Lottable07 = @c_Lottable07,
                              @c_Lottable08 = @c_Lottable08,
                              @c_Lottable09 = @c_Lottable09,
                              @c_Lottable10 = @c_Lottable10,
                              @c_Lottable11 = @c_Lottable11,
                              @c_Lottable12 = @c_Lottable12,
                              @n_UCC_Qty = @n_UCC_Qty      
                            */                         
                        END -- IF @n_UCC_Qty < @n_QtyLeftToFulfill
                     END 
                     ELSE
                     BEGIN
                        BREAK
                     END
                  END --@n_UCC_Qty <= @n_QtyLeftToFulfill
                  
                  NEXT_UCC_CONSO:   --NJOW03
   
                  FETCH NEXT FROM DynPickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
               END -- while  cursor
               CLOSE DynPickCursor
               DEALLOCATE DynPickCursor
            END
            
            --NJOW03 Reverse partial replen multi-sku ucc. must be conso full case.
            IF @n_continue IN(1,2)
            BEGIN            
               --Reverse replenishment and ucc
               DECLARE CUR_MULTIUCC_PARTIALCONSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT OU.UCCNo                  
                  FROM #TMP_ORDERLINEUCC OU
                  CROSS APPLY (SELECT SUM(U.Qty) AS Qty,
                                      SUM(CASE WHEN U.Status >= '3' THEN U.Qty ELSE 0 END) AS QtyAllocated
                               FROM UCC U(NOLOCK) 
                               WHERE U.UCCNo = OU.UCCNo 
                               AND U.Storerkey = @c_Storerkey                               
                               HAVING COUNT(DISTINCT U.Sku) > 1) UD
                  WHERE UD.Qty <> UD.QtyAllocated       
                  GROUP BY OU.UCCNo      
                                   
               OPEN CUR_MULTIUCC_PARTIALCONSO
               
               FETCH NEXT FROM CUR_MULTIUCC_PARTIALCONSO INTO  @c_UCCNo
               
               WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
               BEGIN
               	  --Reverse UCC
                  UPDATE UCC WITH (ROWLOCK)
             	  	SET Status = '2',
             	  	    Wavekey = ''
             	  	WHERE UCCNo = @c_UCCNo
             	  	AND UCC.Storerkey = @c_Storerkey
             	  	AND UCC.Wavekey = @c_Wavekey
             	  	AND UCC.Status = '3'
             	  	
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63700
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCCC Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  END             	  	 
             	  	
             	  	--Reverse Replenishment
             	  	DELETE REPLENISHMENT
             	  	WHERE Storerkey = @c_Storerkey
             	  	AND RefNo = @c_UCCNo
             	  	AND ReplenishmentGroup = @c_TaskId
             	  	AND Wavekey = @c_Wavekey
             	  	AND ToLoc = @c_MultiUCCToLoc
             	  	
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63710
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Replenishment Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  END           
                  
                  --Reverse WaveOrderLn
                  UPDATE WaveOrderLn WITH (ROWLOCK) 
                  SET WaveOrderLn.OpenQty = WaveOrderLn.OpenQty + OU.Qty,
                      WaveOrderLn.QtyAllocated = WaveOrderLn.QtyAllocated - OU.Qty
                  FROM #TMP_ORDERLINEUCC OU
                  JOIN WaveOrderLn ON OU.Orderkey = WaveOrderLn.Orderkey AND OU.OrderLineNumber = WaveOrderLn.OrderLineNumber
                  WHERE OU.UCCNo = @c_UCCNo                  

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63720
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  END           

                  FETCH NEXT FROM CUR_MULTIUCC_PARTIALCONSO INTO @c_UCCNo
               END               
               CLOSE CUR_MULTIUCC_PARTIALCONSO
               DEALLOCATE CUR_MULTIUCC_PARTIALCONSO                              
            END
            
         END -- IF EXISTS(SELECT 1 FROM #TempDynamicPick)
         DROP TABLE #TempDynamicLoc
         DROP TABLE #TempDynamicPick
         DROP TABLE #TMP_ORDERLINEUCC --NJOW03
      END -- Select OpenQty > 0
   
   END -- @n_continue=1 OR @n_continue=2
   -- Dynamic Pick Allocation Completed

   IF @b_debug = 1
   BEGIN
      select 'continue value : ', @n_continue
      --SELECT * FROM WaveOrderLn
   END
   
   IF @b_debug = 1
   BEGIN
      Print 'End Dynamic Pick Face Replenishment...'
      PRint ''
      Print 'Start Allocate from Pick Location...' --Pick loose from pick face/case/dynamicpk. By order. Generate pickdetail (PP)
   END

   --tlting01
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   
      BEGIN TRAN
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_OrderLineIdx = ''
      SELECT @c_PrevOrderkey = '' 
      WHILE 1=1 AND (@n_continue=1 OR @n_continue=2)
      BEGIN
         SELECT @c_OrderLineIdx = MIN(WaveOrderLn.OrderKey + WaveOrderLn.OrderLineNumber)
         FROM   WaveOrderLn (NOLOCK)
         WHERE  WaveKey = @c_WaveKey
         AND    WaveOrderLn.OrderKey + WaveOrderLn.OrderLineNumber > @c_OrderLineIdx
   
         IF @b_debug = 1
         BEGIN
            Print 'orderkey + orderline : ' + @c_OrderLineIdx
         END
   
         IF RTRIM(@c_OrderLineIdx) IS NULL OR RTRIM(@c_OrderLineIdx) = ''
            BREAK
   
         SELECT @c_OrderKey = SubString(@c_OrderLineIdx, 1, 10)
         SELECT @c_OrderLineNumber = SubString(@c_OrderLineIdx, 11, 5)
         
         --279705 start
         --IF @c_PrevOrderkey <> @c_Orderkey
         --BEGIN
            SELECT @c_Pickslipno = ''
             
            SELECT @c_Pickslipno = Pickheaderkey 
            FROM PICKHEADER (NOLOCK)
            WHERE Orderkey = @c_Orderkey
                
            IF ISNULL(@c_PickslipNo,'') = ''
            BEGIN
               SELECT @b_success = 0
               EXECUTE   nspg_getkey
                  'PICKSLIP'
                  , 9
                  , @c_PickSlipNo OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                
               IF @b_success = 1
                  SELECT @c_PickSlipNo = 'P' + RTRIM(@c_PickSlipNo)
               ELSE
                  BREAK
                  
               INSERT PickHeader (Pickheaderkey, Wavekey, Orderkey, zone, picktype)
               VALUES (@c_PickSlipNo, @c_Wavekey, @c_Orderkey, '3','0')
            END            
        --END
   
         SELECT @c_Facility     = WaveOrderLn.Facility,
                @c_WaveKey      = WaveOrderLn.WaveKey,
                @c_Sku          = WaveOrderLn.SKU,
                @c_StorerKey    = WaveOrderLn.StorerKey,
                @n_OpenQty      = WaveOrderLn.OpenQty,
                @n_QtyAllocated = WaveOrderLn.QtyAllocated,
                @n_QtyPicked    = WaveOrderLn.QtyPicked,
                @n_QtyReplenish = WaveOrderLn.QtyReplenish,
                @c_UOM          = WaveOrderLn.UOM,
                @c_PackKey      = WaveOrderLn.PackKey,
                @c_Status       = WaveOrderLn.Status,
                @c_Lottable01   = WaveOrderLn.Lottable01,
                @c_Lottable02   = WaveOrderLn.Lottable02,
                @c_Lottable03   = WaveOrderLn.Lottable03,
                @d_Lottable04   = WaveOrderLn.Lottable04,
                @d_Lottable05   = WaveOrderLn.Lottable05,
                @c_Lottable06   = WaveOrderLn.Lottable06,  
                @c_Lottable07   = WaveOrderLn.Lottable07,  
                @c_Lottable08   = WaveOrderLn.Lottable08,  
                @c_Lottable09   = WaveOrderLn.Lottable09,  
                @c_Lottable10   = WaveOrderLn.Lottable10,  
                @c_Lottable11   = WaveOrderLn.Lottable11,  
                @c_Lottable12   = WaveOrderLn.Lottable12,  
                @d_Lottable13   = WaveOrderLn.Lottable13,  
                @d_Lottable14   = WaveOrderLn.Lottable14,  
                @d_Lottable15   = WaveOrderLn.Lottable15,  
                @c_Lottable01Label = SKU.Lottable01Label,    
                @c_Lottable02Label = SKU.Lottable02Label,    
                @c_Lottable03Label = SKU.Lottable03Label,    
                @c_Lottable04Label = SKU.Lottable04Label,    
                @c_Lottable05Label = SKU.Lottable05Label,
                @c_Lottable06Label = SKU.Lottable06Label,  
                @c_Lottable07Label = SKU.Lottable07Label,  
                @c_Lottable08Label = SKU.Lottable08Label,  
                @c_Lottable09Label = SKU.Lottable09Label,  
                @c_Lottable10Label = SKU.Lottable10Label,  
                @c_Lottable11Label = SKU.Lottable11Label,  
                @c_Lottable12Label = SKU.Lottable12Label,  
                @c_Lottable13Label = SKU.Lottable13Label,  
                @c_Lottable14Label = SKU.Lottable14Label,  
                @c_Lottable15Label = SKU.Lottable15Label,
                @c_Status = WaveOrderLn.Status, --NJOW01
                @c_c_Country = ORDERS.c_Country, --NJOW01  
                @c_OrderGroup = ORDERS.OrderGroup --NJOW02           
         FROM WaveOrderLn (NOLOCK)
         JOIN ORDERS (NOLOCK) ON WaveOrderLn.Orderkey = ORDERS.Orderkey --NJOW01
         JOIN  SKU (NOLOCK) ON (SKU.StorerKey = WaveOrderLn.StorerKey AND SKU.SKU = WaveOrderLn.SKU)
         WHERE WaveOrderLn.OrderKey = @c_OrderKey
         AND   WaveOrderLn.OrderLineNumber = @c_OrderLineNumber
   
         SELECT @c_country = c_country
         FROM ORDERS (NOLOCK)
         WHERE OrderKey = @c_OrderKey
   
         SELECT @c_ExecStatement =
            'DECLARE PickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
            'SELECT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.ID, LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked ' +
            'FROM LOTxLOCxID (NOLOCK) ' +
            'JOIN LotAttribute (NOLOCK) ON (LOTxLOCxID.LOT = LotAttribute.LOT) ' +
            'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.Loc) ' +
            'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
            'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
            'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
            'WHERE LotAttribute.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
            'AND   LotAttribute.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
            'AND   (SKUxLOC.LocationType IN (''CASE'', ''PICK'') OR LOC.LocationType = ''CASE'' OR LOC.LocationType = ''DYNAMICPK'') ' +
            'AND   LOC.LocationFlag <> ''HOLD'' ' +
            'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
            'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0 '
   
         IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
         BEGIN
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
               ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
         END
               
         IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '  
     
         IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''  
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '  
            
         --NJOW01
         IF @c_Status = 'F'
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND ' + RTRIM(@c_Filter_Notes) + ' '  
            
   --      IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
   --      BEGIN
   --         SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
   --            ' ORDER By LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
   --      END
   --      ELSE
         BEGIN
         	  IF ISNULL(@c_Sort_Notes2,'') <> ''  --NJOW01
         	     SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' ORDER BY ' + RTRIM(@c_Sort_Notes2)
         	  ELSE   
                SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  ' ORDER By LotAttribute.Lottable05, LotAttribute.lot, SKUxLOC.LocationType, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
         END
   
         IF @b_debug = 2
         BEGIN
            Print @c_ExecStatement
         END
   
         --EXEC sp_executesql @c_ExecStatement
         EXEC sp_executesql @c_ExecStatement,   --NJOW01
               N'@c_c_Country NVARCHAR(30), @c_OrderGroup NVARCHAR(20)', --NJOW02
               @c_c_Country,
               @c_OrderGroup  --NJOW02            
   
         OPEN PickCursor
         SELECT @n_err = @@ERROR --, @n_cnt = @@CURSOR_ROWS
         IF @n_err = 16905 -- OR @n_cnt = 0
         BEGIN
            -- SELECT @n_continue = 4
            CLOSE PickCursor
            DEALLOCATE PickCursor
            BREAK
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63730   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            GOTO RETURN_SP
         END
         ELSE
         BEGIN
            SELECT @n_CursorOpen = 1
         END
   
         SELECT @n_QtyLeftToFulfill = @n_OpenQty
         SELECT @n_AllocateQty = 0
   
         FETCH NEXT FROM PickCursor INTO
            @c_Lot, @c_Loc, @c_ID, @n_LOT_Qty
   
         WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
         BEGIN
            IF @n_LOT_Qty > 0 AND @n_QtyLeftToFulfill > 0
            BEGIN
               IF @n_LOT_Qty > @n_QtyLeftToFulfill
                  SELECT @n_AllocateQty = @n_QtyLeftToFulfill
               ELSE
                  SELECT @n_AllocateQty = @n_LOT_Qty
   
               SELECT @b_success = 0
               EXECUTE   nspg_getkey
               'PickDetailKey'
               , 10
               , @c_PickDetailKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
   
               IF @b_success = 1
               BEGIN
                  -- select @n_AllocateQty '@n_AllocateQty'
                  SELECT @c_Zone = PutawayZone
                  FROM LOC (NOLOCK)
                  WHERE Loc = @c_Loc
   
                  INSERT INTO PICKDETAIL ( PickDetailKey,    Caseid,        PickHeaderkey,    OrderKey,
                                           OrderLineNumber,  Lot,           Storerkey,        Sku,
                                           PackKey,          UOM,           UOMQty,           Qty,
                                           Loc,              ID,            Cartongroup,      Cartontype,
                                           DoReplenish,      replenishzone, docartonize,      Trafficcop,
                                           PickMethod,       PickSlipNo,    WaveKey)
                  VALUES (@c_PickDetailKey,       '',        '',                  @c_OrderKey,
                          @c_OrderLineNumber,     @c_LOT,    @c_Storerkey,        @c_Sku,
                          @c_PackKey,             '6',       @n_AllocateQty,      @n_AllocateQty,
                          @c_Loc,                 @c_ID,     '',                  'PP',
                          '',                     '',        'N',                 'U',
                          '8',                    @c_PickSlipNo,                  @c_WaveKey)
   
                  SELECT @n_err = @@ERROR, @n_cnt_sql = @@ROWCOUNT
                  SELECT @n_cnt = COUNT(*) FROM PICKDETAIL (NOLOCK) WHERE PICKDETAILKEY = @c_pickdetailkey
                  IF (@b_debug = 1 or @b_debug = 2) and (@n_cnt_sql <> @n_cnt)
                  BEGIN
                     print 'INSERT PickDetail @@ROWCOUNT gets wrong'
                     select '@@ROWCOUNT' = @n_cnt_sql, 'COUNT(*)' = @n_cnt
                  END
                  IF NOT (@n_err = 0 AND @n_cnt = 1)
                  BEGIN
                     SELECT @b_PickInsertSuccess = 0
                     SELECT @n_continue = 3
                  END
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     IF @n_AllocateQty = @n_QtyLeftToFulfill
                     BEGIN
                        DELETE FROM WaveOrderLn WITH(ROWLOCK) --GOH01
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
   
                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_AllocateQty
                     END -- @n_LOT_Qty = @n_QtyLeftToFulfill
                     ELSE IF @n_AllocateQty < @n_QtyLeftToFulfill
                     BEGIN
                        UPDATE WaveOrderLn WITH(ROWLOCK) --GOH01
                        SET OpenQty = OpenQty - @n_LOT_Qty,
                            QtyAllocated = QtyAllocated + @n_AllocateQty
                        WHERE OrderKey = @c_OrderKey
                        AND   OrderLineNumber = @c_OrderLineNumber
   
                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_AllocateQty
                     END -- IF @n_LOT_Qty < @n_QtyLeftToFulfill
                  END -- @n_continue = 1 OR @n_continue = 2
               END -- @b_success = 1, Get PickDetail Key
            END -- @n_LOT_Qty <= @n_QtyLeftToFulfill
            ELSE
            BEGIN
               BREAK 
            END
   
            FETCH NEXT FROM PickCursor INTO
               @c_Lot, @c_Loc, @c_ID, @n_LOT_Qty
         END -- while  cursor
         CLOSE PickCursor
         DEALLOCATE PickCursor
         
         SELECT @c_PrevOrderkey = @c_Orderkey --279705
      END -- While 2
   END

   IF @b_debug = 1
   BEGIN
      Print 'End Allocate from Pick Location...'
      PRint ''
      Print 'Start Replenisment from Bulk to Pick Loc...' 
   END

   --tlting01
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      
      BEGIN TRAN
   END

   -- complete Pick Location allocation
   -- if still have outstanding.....
   -- Create replenishment...
   -- Replenish conso remaining qty by UCC from bulk to pick face. (pickface)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM WaveOrderLn (NOLOCK) WHERE  WaveKey = @c_WaveKey and OpenQty > 0 )
      BEGIN
         CREATE TABLE #TempReplen
         (PickSeq      smallint IDENTITY(1,1) PRIMARY KEY,
          StorerKey    NVARCHAR(15),
          SKU          NVARCHAR(20),
          Lottable01   NVARCHAR(18), 
          Lottable02   NVARCHAR(18),
          Lottable03   NVARCHAR(18),
          Lottable06   NVARCHAR(30),  
          Lottable07   NVARCHAR(30),  
          Lottable08   NVARCHAR(30),  
          Lottable09   NVARCHAR(30),  
          Lottable10   NVARCHAR(30),  
          Lottable11   NVARCHAR(30),  
          Lottable12   NVARCHAR(30),  
          Qty          int,
          Status       NVARCHAR(10), --NJOW01
          C_Country    NVARCHAR(30) NULL, --NJOW01
          OrderGroup   NVARCHAR(20)) --NJOW02
   
         CREATE TABLE #TempPickLoc
            (Rowref       INT IDENTITY(1,1) PRIMARY KEY,
             StorerKey    NVARCHAR(15),
             Sku          NVARCHAR(20),
             LOC          NVARCHAR(10),
             Status       NVARCHAR(1),
             Lottable01   NVARCHAR(18),
             Lottable02   NVARCHAR(18),
             Lottable03   NVARCHAR(18))
   
         CREATE TABLE #TempSkuXLoc
            (StorerKey    NVARCHAR(15),
             Sku          NVARCHAR(20),
             LOC          NVARCHAR(10),
             QtyLocationLimit INT,
             QtyAvailable INT)
   
         INSERT INTO #TempReplen (StorerKey, SKU, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07,   
               Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Qty, STATUS, C_Country, OrderGroup)   --NJOW02
         SELECT WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03, WaveOrderLn.Lottable06, WaveOrderLn.Lottable07,   
               WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12,        
               SUM(WaveOrderLn.OpenQty) as Qty,
               WaveOrderLn.Status, CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.c_Country ELSE '' END, --NJOW01  --NJOW01
               CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.OrderGroup ELSE '' END  --NJOW02            
         FROM  WaveOrderLn (NOLOCK)
         JOIN ORDERS (NOLOCK) ON WaveOrderLn.Orderkey = ORDERS.Orderkey --NJOW01
         WHERE  WaveOrderLn.WaveKey = @c_WaveKey AND WaveOrderLn.OpenQty > 0
         GROUP BY WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03,
                  WaveOrderLn.Lottable06, WaveOrderLn.Lottable07, WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12,
                  WaveOrderLn.Status, CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.c_Country ELSE '' END, --NJOW01
                  CASE WHEN WaveOrderLn.Status = 'F' THEN ORDERS.OrderGroup ELSE '' END --NJOW02               
         ORDER BY WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01
   
         IF (@b_debug = 1 or @b_debug = 2)
         BEGIN
            SELECT '#TempReplen', * FROM #TempReplen (NOLOCK)
         END
   
         INSERT INTO #TempPickLoc (Storerkey, Sku, LOC, STATUS, Lottable01,
                     Lottable02, Lottable03)
         SELECT DISTINCT SL.Storerkey, SL.Sku, SL.LOC, '0', ISNULL(LA.Lottable01,''), 
                ISNULL(LA.Lottable02,''), ISNULL(LA.Lottable03,'')
         FROM WaveOrderLn (NOLOCK) 
         JOIN SKUxLOC AS SL (NOLOCK)  ON (WaveOrderLn.StorerKey = SL.StorerKey AND WaveOrderLn.SKU = SL.SKU)
         LEFT OUTER JOIN LOTxLOCxID AS lli (NOLOCK) ON lli.StorerKey = SL.StorerKey AND lli.Sku = SL.Sku AND lli.Loc = SL.Loc AND (LLI.Qty-LLI.QtyPicked > 0)  
         LEFT OUTER JOIN LOTATTRIBUTE AS LA (NOLOCK) ON LA.Lot = lli.Lot  
         WHERE  WaveKey = @c_WaveKey  
         AND    SL.LocationType IN ('PICK', 'CASE')
         AND    WaveOrderLn.OpenQty > 0 
         
         -- Update the #TempPick if there is the pending replenishment records.
         UPDATE TPC
            SET TPC.Lottable01 = LA.Lottable01, 
                TPC.Lottable02 = LA.Lottable02, 
                TPC.Lottable03 = LA.Lottable03  
         FROM #TempPickLoc TPC 
         JOIN REPLENISHMENT AS RPL WITH (NOLOCK) 
               ON RPL.StorerKey = TPC.StorerKey AND RPL.Sku = TPC.Sku AND RPL.ToLoc = TPC.LOC
         JOIN LOTATTRIBUTE AS LA WITH (NOLOCK) ON LA.Lot = RPL.Lot 
         WHERE RPL.Confirmed = 'N' 
         AND   RPL.Qty > 0       
         
         INSERT INTO #TempSkuXLoc (Storerkey, Sku, LOC, QtyLocationLimit, QtyAvailable)
         SELECT SL.Storerkey, SL.Sku, SL.LOC, SL.QtyLocationLimit, SUM(SL.Qty - SL.QtyPicked)     
         FROM SKUxLOC AS SL (NOLOCK)  
         JOIN (SELECT DISTINCT Storerkey, Sku, Loc FROM #TempPickLoc) AS TPL ON SL.StorerKey = TPL.StorerKey AND SL.SKU = TPL.SKU AND SL.Loc = TPL.Loc
         GROUP BY SL.Storerkey, SL.Sku, SL.LOC, SL.QtyLocationLimit
   
         -- Update the #TempPick if there is the pending replenishment records.
         UPDATE TSL
            SET TSL.QtyAvailable = TSL.QtyAvailable + RPL.Qty
         FROM #TempSkuXLoc TSL 
         JOIN (SELECT R.Storerkey, R.Sku, R.ToLoc, SUM(R.Qty) AS QTY 
               FROM REPLENISHMENT R (NOLOCK) 
               WHERE R.Confirmed = 'N'
               AND R.Qty > 0
               GROUP BY R.Storerkey, R.Sku, R.ToLoc) AS RPL  
               ON RPL.StorerKey = TSL.StorerKey AND RPL.Sku = TSL.Sku AND RPL.ToLoc = TSL.LOC
   
         IF (@b_debug = 1 or @b_debug = 2)
         BEGIN
            SELECT '#TempPickLoc', * FROM #TempPickLoc (NOLOCK)
            SELECT '#TempSkuXLoc', * FROM #TempSkuXLoc (NOLOCK)
         END
   
         IF EXISTS(SELECT 1 FROM #TempReplen)
         BEGIN
            SELECT @n_PickSeq = 0
   
            WHILE 1=1 AND (@n_continue=1 OR @n_continue=2)
            BEGIN
               SELECT @n_PickSeq = MIN(PickSeq)
               FROM   #TempReplen
               WHERE  PickSeq > @n_PickSeq
   
               IF @n_PickSeq IS NULL OR @n_PickSeq = 0
                  BREAK
   
               SELECT @c_StorerKey = SKU.StorerKey,
                      @c_SKU       = SKU.SKU,
                      @c_Lottable01 = #TempReplen.Lottable01,
                      @c_Lottable02 = #TempReplen.Lottable02,
                      @c_Lottable03 = #TempReplen.Lottable03,                                      
                      @c_Lottable06       = #TempReplen.Lottable06,  
                      @c_Lottable07       = #TempReplen.Lottable07,  
                      @c_Lottable08       = #TempReplen.Lottable08,  
                      @c_Lottable09       = #TempReplen.Lottable09,  
                      @c_Lottable10       = #TempReplen.Lottable10,  
                      @c_Lottable11       = #TempReplen.Lottable11,  
                      @c_Lottable12       = #TempReplen.Lottable12,  
                      @n_OpenQty    = #TempReplen.Qty,    
                      @c_Lottable01Label = SKU.Lottable01Label,    
                      @c_Lottable02Label = SKU.Lottable02Label,    
                      @c_Lottable03Label = SKU.Lottable03Label,    
                      @c_Lottable04Label = SKU.Lottable04Label,    
                      @c_Lottable05Label = SKU.Lottable05Label, 
                      @c_Lottable06Label  = SKU.Lottable06Label,  
                      @c_Lottable07Label  = SKU.Lottable07Label,  
                      @c_Lottable08Label  = SKU.Lottable08Label,  
                      @c_Lottable09Label  = SKU.Lottable09Label,  
                      @c_Lottable10Label  = SKU.Lottable10Label,  
                      @c_Lottable11Label  = SKU.Lottable11Label,  
                      @c_Lottable12Label  = SKU.Lottable12Label,  
                      @c_Lottable13Label  = SKU.Lottable13Label,  
                      @c_Lottable14Label  = SKU.Lottable14Label,  
                      @c_Lottable15Label  = SKU.Lottable15Label,  
                      @c_PutawayZone     = SKU.PutawayZone,
                      @c_Packkey = SKU.Packkey,
                      @c_UOM = PACK.PackUOM3,
                      @c_Status = #TempReplen.Status, --NJOW01
                      @c_C_Country = #TempReplen.c_Country, --NJOW01
                      @c_OrderGroup = #TempReplen.OrderGroup --NJOW02                     
               FROM #TempReplen
               JOIN  SKU (NOLOCK) ON (SKU.StorerKey = #TempReplen.StorerKey AND SKU.SKU = #TempReplen.SKU)
               JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
               WHERE #TempReplen.PickSeq = @n_PickSeq
   
               SELECT @c_ExecStatement =
                  'DECLARE PickCursor CURSOR READ_ONLY FOR  ' +
                  'SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCC.Qty ' +
                  'FROM UCC (NOLOCK) ' +
                  'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
                  'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
                  'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
                  'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
                  'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
                  'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
                  'LEFT JOIN (SELECT DISTINCT Storerkey, SKU, Lottable01, Lottable02, Lottable03 
                              FROM #TempPickLoc  
                              WHERE (ISNULL(Lottable01,'''') <> ''''  
                              OR ISNULL(Lottable02,'''') <> ''''  
                              OR ISNULL(Lottable03,'''') <> '''')) AS TP ON LOTXLOCXID.Storerkey = TP.Storerkey AND LOTXLOCXID.Sku = TP.Sku AND 
                                                                               LOTATTRIBUTE.Lottable01 = TP.Lottable01 AND 
                                                                               LOTATTRIBUTE.Lottable02 = TP.Lottable02 AND 
                                                                               LOTATTRIBUTE.Lottable03 = TP.Lottable03 ' +           
                  'OUTER APPLY (SELECT TOP 1 R.Replenishmentkey
                                FROM REPLENISHMENT R (NOLOCK) 
                                WHERE R.RefNo = UCC.UCCNo 
                                AND R.Storerkey = UCC.Storerkey
                                AND R.Wavekey = @c_Wavekey
                                AND R.ReplenishmentGroup = @c_TaskID
                                AND R.Confirmed = ''N''
                                AND R.Toloc = @c_MultiUCCToLoc
                                AND R.Remark = ''PICKFACE'') REPUCC ' +  --NJOW03                                                                                                             
                  'WHERE UCC.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
                  'AND   UCC.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
                  'AND   UCC.Status BETWEEN ''1'' AND ''4'' ' +
                  'AND   UCC.Status <> ''3'' ' +
                  'AND   UCC.Qty > 0 ' +
                  'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
                  'AND   LOC.LocationType = ''OTHER'' ' +
                  'AND   LOC.LocationFlag <> ''HOLD'' ' +
                  'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
                  'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '
               
               SET @c_ExecStatement2 = ''  --NJOW01                
               IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' ' --NJOW01
               END
         
               IF RTRIM(ISNULL(@c_Lottable02,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' '  --NJOW01
               END   
     
               IF RTRIM(ISNULL(@c_Lottable03,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable03 = N''' + RTRIM(@c_Lottable03) + ''' '  --NJOW01
               END 
     
               IF RTRIM(ISNULL(@c_Lottable06,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable06 = N''' + RTRIM(@c_Lottable06) + ''' '  --NJOW01
               END
     
               IF RTRIM(ISNULL(@c_Lottable07,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable07 = N''' + RTRIM(@c_Lottable07) + ''' '  --NJOW01
               END
     
               IF RTRIM(ISNULL(@c_Lottable08,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable08 = N''' + RTRIM(@c_Lottable08) + ''' '  --NJOW01
               END
     
               IF RTRIM(ISNULL(@c_Lottable09,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable09 = N''' + RTRIM(@c_Lottable09) + ''' '  --NJOW01
               END
     
               IF RTRIM(ISNULL(@c_Lottable10,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable10 = N''' + RTRIM(@c_Lottable10) + ''' '  --NJOW01
               END
     
               IF RTRIM(ISNULL(@c_Lottable11,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable11 = N''' + RTRIM(@c_Lottable11) + ''' '  --NJOW01
               END
   
               IF RTRIM(ISNULL(@c_Lottable12,'')) <> ''  
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND LotAttribute.Lottable12 = N''' + RTRIM(@c_Lottable12) + ''' '  --NJOW01
               END
   
               --NJOW01
               IF @c_Status = 'F'
               BEGIN
                  SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' AND ' + RTRIM(@c_Filter_Notes) + ' '  
                  SELECT @c_ExecStatement2 = RTRIM(@c_ExecStatement2) + ' AND ' + RTRIM(@c_Filter_Notes) + ' '  --NJOW01
               END   
               
   --            IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
   --            BEGIN
   --               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
   --                  ' ORDER By LotAttribute.Lottable02, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
   --            END
   --            ELSE
               BEGIN
               	 IF ISNULL(@c_Sort_Notes2,'') <> ''  --NJOW01
               	    SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) + ' ORDER BY CASE WHEN REPUCC.Replenishmentkey IS NOT NULL THEN 1 ELSE 2 END,' + RTRIM(@c_Sort_Notes2) --NJOW03
               	 ELSE   
                     SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                       ' ORDER By CASE WHEN REPUCC.Replenishmentkey IS NOT NULL THEN 1 ELSE 2 END, CASE WHEN ISNULL(TP.Sku,'''') <> '''' THEN 0 ELSE 1 END, LotAttribute.Lottable05, LotAttribute.lot, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '--NJOW03
                    -- ' ORDER By LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
               END
   
               IF @b_debug = 1
               BEGIN
                  Print @c_ExecStatement
               END
                           
               --NJOW01
               --Search replenishment start 
               SET @c_FoundReplenishmentkey = ''
               SET @n_ReplenAvailableQty = 0
               SELECT @c_ExecStatement2 =
                  'SELECT TOP 1 @c_Replenishmentkey = REP.Replenishmentkey, ' +
                  '             @n_ReplenAvailableQty = REP.Qty - REP.QtyInPickLoc ' +
                  'FROM REPLENISHMENT REP (NOLOCK) ' +
                  'JOIN LOTATTRIBUTE (NOLOCK) ON REP.Lot = LOTATTRIBUTE.Lot ' +
                  'JOIN LOC (NOLOCK) ON REP.FromLoc = LOC.Loc ' +
                  'JOIN SKUXLOC (NOLOCK) ON REP.Storerkey = SKUXLOC.Storerkey AND REP.Sku = SKUXLOC.Sku AND REP.Toloc = SKUXLOC.Loc ' +
                  'WHERE REP.Wavekey = @c_Wavekey ' +
                  'AND REP.Storerkey = @c_Storerkey ' +
                  'AND REP.Sku = @c_Sku ' +
                  'AND SKUXLOC.LocationType IN(''PICK'',''CASE'') ' +
                  'AND REP.Qty - REP.QtyInPickLoc > 0 ' +
                  'AND REP.Confirmed = ''N'' ' + 
                  'AND REP.Remark=''PICKFACE'' ' +              
                  @c_ExecStatement2
   
               EXEC sp_executesql @c_ExecStatement2,   --NJOW01
               N'@c_OrderGroup NVARCHAR(20), @c_c_Country NVARCHAR(30), @c_Wavekey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Replenishmentkey NVARCHAR(10) OUTPUT, @n_ReplenAvailableQty INT OUTPUT',  --NJOW02
               @c_OrderGroup,  --NJOW02
               @c_c_Country,
               @c_Wavekey,
               @c_Storerkey,
               @c_Sku,
               @c_FoundReplenishmentkey OUTPUT,
               @n_ReplenAvailableQty OUTPUT
               
               IF ISNULL(@c_FoundReplenishmentkey,'') <> '' AND @n_ReplenAvailableQty > 0
               BEGIN
               	  IF @n_ReplenAvailableQty >= @n_OpenQty
               	  BEGIN
               	  	 UPDATE REPLENISHMENT WITH (ROWLOCK)
               	  	 SET QtyInPickLoc = QtyInPickLoc + @n_OpenQty
               	  	 WHERE Replenishmentkey = @c_FoundReplenishmentkey
               	  	  
                     DELETE FROM #TempReplen
                     WHERE #TempReplen.PickSeq = @n_PickSeq         
                     
                     GOTO NEXT_PICK
               	  END
               	  ELSE
               	  BEGIN
               	  	 SET @n_OpenQty = @n_OpenQty - @n_ReplenAvailableQty
               	  	 
               	  	 UPDATE REPLENISHMENT WITH (ROWLOCK)
               	  	 SET QtyInPickLoc = QtyInPickLoc + @n_ReplenAvailableQty 
               	  	 WHERE Replenishmentkey = @c_FoundReplenishmentkey
               	  	 
               	     UPDATE #TempReplen
                     SET #TempReplen.Qty = #TempReplen.Qty - @n_ReplenAvailableQty
                     WHERE #TempReplen.PickSeq = @n_PickSeq
               	  END
               END            
               --Search replenishment end
   
               --EXEC sp_executesql @c_ExecStatement
               EXEC sp_executesql @c_ExecStatement,   --NJOW01
                  N'@c_c_Country NVARCHAR(30), @c_OrderGroup NVARCHAR(20), @c_Wavekey NVARCHAR(10), @c_TaskID NVARCHAR(10), @c_MultiUCCToLoc NVARCHAR(10)', --NJOW02 NJOW03
                  @c_c_Country,
                  @c_OrderGroup,   --NJOW02            
                  @c_Wavekey,  --NJOW03
                  @c_TaskId,   --NJOW03
                  @c_MultiUCCToLoc  --NJOW03
                  
               OPEN PickCursor
   
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err = 16905
               BEGIN
                  CLOSE PickCursor
                  DEALLOCATE PickCursor
               END
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63740   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
               END
               ELSE
               BEGIN
                  SELECT @n_CursorOpen = 1
               END
   
               SELECT @n_QtyLeftToFulfill = @n_OpenQty
   
               FETCH NEXT FROM PickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
   
               WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
               BEGIN
               	 --IF @b_debug = 1
               	    --SELECT '@c_UCCNo', @c_UCCNo, '@c_Lot', @c_Lot, '@c_Loc',@c_Loc, '@c_ID',@c_ID, '@n_UCC_Qty',@n_UCC_Qty
               	 
               	 --NJOW03 if any sku of the ucc not in the orders
                 /*IF EXISTS(SELECT 1
         	                  FROM UCC U (NOLOCK)
         	                  OUTER APPLY (SELECT SUM(OD.Qty) Qty
         	                               FROM  #TempReplen OD (NOLOCK) 
         	                               WHERE OD.Storerkey = U.Storerkey 
         	                               AND OD.Sku = U.Sku          	                                    	                                               
                                         --AND OD.Lottable01 = @c_Lottable01 
                                         ---AND OD.Lottable02 = @c_Lottable02 
                                         --AND OD.Lottable03 = @c_Lottable03 
                                         --AND OD.Lottable06 = @c_Lottable06 
                                         --AND OD.Lottable07 = @c_Lottable07 
                                         --AND OD.Lottable08 = @c_Lottable08 
                                         --AND OD.Lottable09 = @c_Lottable09 
                                         --AND OD.Lottable10 = @c_Lottable10 
                                         --AND OD.Lottable11 = @c_Lottable11 
                                         --AND OD.Lottable12 = @c_Lottable12
                                         ) OL
         	                  WHERE U.UCCNo = @c_UCCNo
         	                  AND U.Status < '3'
         	                  AND U.Storerkey = @c_Storerkey
         	                  AND OL.Qty IS NULL
         	                  --AND (OL.Qty IS NULL OR OL.Qty < U.Qty) 
         	                  )
         	        BEGIN
         	           GOTO NEXT_UCC_PICKFACE
         	        END*/                   	   
               	    
                  IF @n_UCC_Qty > 0 AND @n_QtyLeftToFulfill > 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'
                     END
                                       
                     EXECUTE nspg_GetKey
                         @keyname       = 'REPLENISHKEY', --Leong01
                         @fieldlength   = 10,
                         @keystring     = @c_ReplenishmentKey  OUTPUT,
                         @b_success     = @b_success   OUTPUT,
                         @n_err         = @n_err       OUTPUT,
                         @c_errmsg      = @c_errmsg    OUTPUT
                     
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                     END
                     ELSE
                     BEGIN                         
                        SET @c_ToLOC = ''
                        
                        --NJOW03
                     	  IF EXISTS(SELECT 1
                     	            FROM UCC (NOLOCK)
                     	            WHERE Storerkey = @c_Storerkey
                     	            AND UCCNo = @c_UCCNo
                     	            HAVING COUNT(DISTINCT Sku) > 1)
                     	  BEGIN
                     	     SELECT @c_Toloc = @c_MultiUCCToLoc
                     	  END                        
                        
                        -- Find pick location using inventoy lottable instead of orderdetail lottable
                        SELECT @c_Lottable01 = LA.Lottable01,
                               @c_Lottable02 = LA.Lottable02,
                               @c_Lottable03 = LA.Lottable03
                        FROM LOTATTRIBUTE LA (NOLOCK) 
                        WHERE LA.Lot = @c_lot
                               
                        -- Find location that already have similar lottables
                        IF ISNULL(RTRIM(@c_ToLOC),'' ) = ''  --NJOW03
                        BEGIN
                           SELECT TOP 1 @c_ToLOC = TPL.LOC
                           FROM   #TempPickLoc TPL  
                           JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TPL.LOC 
                           JOIN   #TempSkuXLoc TSL ON TPL.Storerkey = TSL.Storerkey AND TPL.Sku = TSL.Sku AND TPL.Loc = TSL.Loc
                           WHERE  TPL.Status = '0' 
                           AND    TPL.StorerKey = @c_StorerKey 
                           AND    TPL.SKU = @c_Sku
                           AND    TPL.Lottable01 = @c_Lottable01
                           AND    TPL.Lottable02 = @c_Lottable02 
                           AND    TPL.Lottable03 = @c_Lottable03  
                           AND    (TSL.QtyLocationLimit >= (TSL.QtyAvailable + @n_UCC_Qty) OR TSL.QtyLocationLimit = 0)
                        END
                        
                        IF ISNULL(RTRIM(@c_ToLOC),'' ) = ''
                        BEGIN
                           SELECT TOP 1 @c_ToLOC = TPL.LOC
                           FROM   #TempPickLoc TPL  
                           JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TPL.LOC 
                           JOIN   #TempSkuXLoc TSL ON TPL.Storerkey = TSL.Storerkey AND TPL.Sku = TSL.Sku AND TPL.Loc = TSL.Loc
                           WHERE  TPL.Status = '0' 
                           AND    TPL.StorerKey = @c_StorerKey 
                           AND    TPL.SKU = @c_Sku
                           AND    TPL.Lottable01 = CASE WHEN ISNULL(LOC.NoMixLottable01,'0') = '1' THEN @c_Lottable01 ELSE TPL.Lottable01 END
                           AND    TPL.Lottable02 = CASE WHEN ISNULL(LOC.NoMixLottable02,'0') = '1' THEN @c_Lottable02 ELSE TPL.Lottable02 END 
                           AND    TPL.Lottable03 = CASE WHEN ISNULL(LOC.NoMixLottable03,'0') = '1' THEN @c_Lottable03 ELSE TPL.Lottable03 END                          
                           AND    (TSL.QtyLocationLimit >= (TSL.QtyAvailable + @n_UCC_Qty) OR TSL.QtyLocationLimit = 0)
                        END
   
                        IF ISNULL(RTRIM(@c_ToLOC),'') = '' 
                        BEGIN                        
                           SELECT TOP 1 @c_ToLOC = #TempPickLoc.LOC
                           FROM   #TempPickLoc
                           WHERE  #TempPickLoc.Status = '0'
                           AND    #TempPickLoc.Sku = @c_sku
                           AND    #TempPickLoc.Lottable01 = ''
                           AND    #TempPickLoc.Lottable02 = ''
                           AND    #TempPickLoc.Lottable03 = ''
                           ORDER BY #TempPickLoc.LOC
                           
                        END
   
                        IF @b_debug = 1
                        BEGIN
                           IF ISNULL(RTRIM(@c_ToLOC),'') <> '' 
                              PRINT 'Location Found: '  +  @c_ToLOC
                           ELSE
                              PRINT 'Location Not Found for SKU: ' + @c_sku
                        END 
                                             
                        IF ISNULL(RTRIM(@c_ToLOC),'') = '' 
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = '', @n_err = 63750   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Permanent Pick Location Not Found! (ispWRUCC02)'
                           BREAK
                        END
                          
                        IF @n_continue=1 OR @n_continue=2
                        BEGIN
                           UPDATE UCC  WITH(ROWLOCK) --GOH01  
                              SET Status = '6',   
                                 WaveKey = @c_WaveKey,   
                                 EditDate = GETDATE(),   
                                 EditWho = SUSER_SNAME()    
                           WHERE UCCNo = @c_UCCNo    
                           AND Storerkey = @c_Storerkey  --NJOW03
                           AND Sku = @c_Sku  --NJOW03                                                                          
                           
                           IF @n_UCC_Qty < @n_QtyLeftToFulfill
                               SELECT @n_QtyInPickLOC = @n_UCC_Qty
                           ELSE
                               SELECT @n_QtyInPickLOC = @n_QtyLeftToFulfill
                        
                           INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                               StorerKey,      SKU,       FromLOC,      ToLOC,
                               Lot,            Id,        Qty,          UOM,
                               PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                               RefNo,          Confirmed, ReplenNo,     Wavekey,
                               Remark)
                           VALUES (
                               @c_ReplenishmentKey,       @c_TaskId,
                               @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                               @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                               @c_Packkey,     '1',       0,            @n_QtyInPickLOC,
                               @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey,
                               'Pickface')
                        
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63760   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                              BREAK
                           END
                           
                           UPDATE #TempPickLoc 
                           SET Lottable01 = @c_Lottable01, Lottable02 = @c_Lottable02, Lottable03 = @c_Lottable03
                           WHERE StorerKey = @c_StorerKey
                           AND   SKU = @c_Sku 
                           AND   LOC = @c_ToLoc
                            
                        END
                     END -- IF @b_success = 1
                     
                     IF @n_continue=1 OR @n_continue=2
                     BEGIN
                        IF @n_UCC_Qty >= @n_QtyLeftToFulfill
                        BEGIN
                           DELETE FROM #TempReplen
                           WHERE #TempReplen.PickSeq = @n_PickSeq
                        
                           SELECT @n_QtyLeftToFulfill = 0
                           BREAK
                        END -- @n_UCC_Qty = @n_QtyLeftToFulfill
                        ELSE IF @n_UCC_Qty < @n_QtyLeftToFulfill
                        BEGIN
                           UPDATE #TempReplen
                              SET #TempReplen.Qty = #TempReplen.Qty - @n_UCC_Qty
                           WHERE #TempReplen.PickSeq = @n_PickSeq
                        
                           SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty
                        
                        END -- IF @n_UCC_Qty < @n_QtyLeftToFulfill
                     END -- continue
                  END -- @n_UCC_Qty <= @n_QtyLeftToFulfill
                  ELSE
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        PRINT '@n_UCC_Qty = ' + CAST(@n_UCC_Qty AS VARCHAR(10)) 
                        PRINT '@n_QtyLeftToFulfill=' + CAST(@n_QtyLeftToFulfill AS VARCHAR(10)) 
                     END
                     BREAK
                  END
                  
                  NEXT_UCC_PICKFACE: --NJOW03
   
                  FETCH NEXT FROM PickCursor INTO @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
               END -- while  cursor
               CLOSE PickCursor
               DEALLOCATE PickCursor
               
               NEXT_PICK:
            END
            
            --NJOW03 if partial replen of multi-sku UCC to pickface, include the others sku as well
            IF @n_continue IN(1,2)
            BEGIN
               DECLARE CUR_MULTIUCC_PARTIALPICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT UCC.UCCNo, UCC.Qty, UCC.Sku, UCC.Lot, UCC.Loc, UCC.ID, SKU.Packkey
                  FROM UCC (NOLOCK)
                  JOIN SKU (NOLOCK) ON UCC.Storerkey = SKU.Storerkey AND UCC.Sku = SKU.SKU
                  WHERE UCC.UCCNo IN(SELECT R.Refno
                                     FROM REPLENISHMENT R (NOLOCK)
                                     WHERE R.Storerkey = @c_Storerkey
                                     AND R.Wavekey = @c_Wavekey
                                     AND R.ReplenishmentGroup = @c_TaskID
                                     AND R.Confirmed = 'N'
                                     AND R.Toloc = @c_MultiUCCToLoc
                                     AND R.Remark = 'PICKFACE')
                  AND UCC.Status < '3'
                  AND UCC.Storerkey = @c_Storerkey               
                                                    
               OPEN CUR_MULTIUCC_PARTIALPICK
               
               FETCH NEXT FROM CUR_MULTIUCC_PARTIALPICK INTO @c_UCCNo, @n_UCC_Qty, @c_Sku, @c_Lot, @c_Loc, @c_ID, @c_Packkey
               
               WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
               BEGIN            	
                  UPDATE UCC  WITH(ROWLOCK) 
                     SET Status = '6',   
                        WaveKey = @c_WaveKey,   
                        EditDate = GETDATE(),   
                        EditWho = SUSER_SNAME()    
                  WHERE UCCNo = @c_UCCNo    
                  AND Storerkey = @c_Storerkey  
                  AND Sku = @c_Sku                                                                         
                  
                  SELECT @n_QtyInPickLOC = 0            
                  SET @c_ToLOC = @c_MultiUCCToLoc
                  
                  EXECUTE nspg_GetKey
                      @keyname       = 'REPLENISHKEY', 
                      @fieldlength   = 10,
                      @keystring     = @c_ReplenishmentKey  OUTPUT,
                      @b_success     = @b_success   OUTPUT,
                      @n_err         = @n_err       OUTPUT,
                      @c_errmsg      = @c_errmsg    OUTPUT
                  
                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                  END                  
                  
                  INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                      StorerKey,      SKU,       FromLOC,      ToLOC,
                      Lot,            Id,        Qty,          UOM,
                      PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                      RefNo,          Confirmed, ReplenNo,     Wavekey,
                      Remark)
                  VALUES (
                      @c_ReplenishmentKey,       @c_TaskId,
                      @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                      @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                      @c_Packkey,     '1',       0,            @n_QtyInPickLOC,
                      @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey,
                      'Pickface')
                  
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63770   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
                  END        
                         	  
                  FETCH NEXT FROM CUR_MULTIUCC_PARTIALPICK INTO @c_UCCNo, @n_UCC_Qty, @c_Sku, @c_Lot, @c_Loc, @c_ID, @c_Packkey
               END
               CLOSE CUR_MULTIUCC_PARTIALPICK
               DEALLOCATE CUR_MULTIUCC_PARTIALPICK            	
            END                        
         END -- IF EXISTS(SELECT 1 FROM #TempReplen)
                  
         DROP TABLE #TempReplen
      END -- Select OpenQty > 0
   END -- @n_continue=1 OR @n_continue=2
   IF @b_debug = 1
   BEGIN
      PRint ''
      Print 'End Replenisment from Bulk to Pick Loc...'
      PRINT 'Error: ' + @c_errmsg
   END
   -- Last Replenishment
   
   -- clean up waveorderln table
   DELETE WaveOrderLn WHERE WaveOrderLn.WaveKey = @c_WaveKey
   
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
      
   RETURN_SP:

   --tlting01   
   IF @b_debug = 0
   BEGIN
      WHILE @@TRANCOUNT < @n_starttcnt
         BEGIN TRAN
   END      	

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF (SELECT CURSOR_STATUS('local','PickCursor')) >= -1      --NJOW03
      BEGIN
         IF (SELECT CURSOR_STATUS('local','PickCursor')) > -1  --NJOW03
         BEGIN
            CLOSE PickCursor
         END
         DEALLOCATE PickCursor
      END
      
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispWRUCC02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END   

GO