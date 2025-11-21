SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Stored Procedure: ispWRUCC01                                                 */
/* Creation Date: 29-Jun-2004                                                   */
/* Copyright: IDS                                                               */
/* Written by: Shong                                                            */
/*                                                                              */
/* Purpose: UCC Allocation Special Design for Timberland Hong Kong              */
/*          Original: ispWaveReplenUCCAlloc                            	        */
/*                                                                              */
/* Called By: From Wave Maintenance Screen                                      */
/*                                                                              */
/* PVCS Version: 1.1 	                                                        */
/*                                                                              */
/* Version: 5.4                                                                 */
/*                                                                              */
/* Data Modifications:                                                          */
/*                                                                              */
/* Updates:                                                                     */
/* Date         Author     Ver     Purposes                                     */
/* 14-Sep-2006  Shong              SOS58649 - Found "HOLD" Lot items can be     */
/*                                 allocated under Wave                         */
/* 16-Oct-2006	 June			        SOS58839 - Filter out UCC details Qty <= 0	  */
/*                                                                              */
/* 01-Mar-2007  Shong              SOS69809 - Insert Null Value into PickSlipNo */
/*                                          - Fixed Dynamic Pick Loc Issues     */
/* 19-Mar-2010  Leong      1.1     Bug Fix: Change GetKey from REPLENISHMENT to */
/*                                          REPLENISHKEY (Leong01)              */
/* 31-May-2013  Shong      1.2     SOS279705 VFTBL-UCC New Interface with Diff  */
/*                                 Data Mapping                                 */
/* 04-Nov-2013  GTGoh      1.3     Add in NOLOCK and ROWLOCK (GOH01)            */  
/* 13-Nov-2013  GTGOH      1.4     Move Insert PickHeader to top (GOH01)        */ 
/* 20-May-2014  TKLIM      1.5     Added Lottables 06-15                        */  
/* 06-Aug-2015  TLTING01   1.1     Blocking Tune                                */
/********************************************************************************/

CREATE PROCEDURE [dbo].[ispWRUCC01]
	@c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
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
   SELECT @b_debug = 1
ELSE
   SELECT @b_debug = 0

SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0


DECLARE @c_TaskID         NVARCHAR(25),
			@cZipCodeTo	     NVARCHAR(15),
        	@cTransmitlogKey NVARCHAR(10),
			@c_country       NVARCHAR(30),
			@c_COO           NVARCHAR(18) -- lottable01

IF @n_starttcnt = 0 
   BEGIN TRAN

IF @n_continue=1 OR @n_continue=2
BEGIN
	 IF EXISTS (SELECT 1 
              FROM  REPLENISHMENT WITH (NOLOCK)
              WHERE ReplenNo = @c_WaveKey 
              AND Confirmed = 'S')
              --AND Confirmed <> 'N')
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
   --WHERE r.Wavekey = @c_WaveKey
   
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
-- Start inserting the records into Temp WaveOrderLine
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
	,			@c_SysLottable01	   NVARCHAR(18)
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
   ,        @c_ExecStatement     NVARCHAR(3000)
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
	,			@c_PrevOrderkey	   NVARCHAR(10)
	,			@c_PickSlipNo		   NVARCHAR(10)
	,			@c_LabelNo			   NVARCHAR(20)
	,			@n_Carton				int
	,			@c_Zone				   NVARCHAR(10)
-- Added by Shong on 27-Jul-2004
-- Reuse Dynamic Pick Location if Fully occupied
   ,        @c_DynamicLocLoop    NVARCHAR(2)
   ,        @n_QtyInPickLOC 		int -- SOS38467
   ,        @c_PrevPutAwayZone   NVARCHAR(10) -- SOS69809

   DECLARE @n_Pickslip_cnt INT  
   DECLARE @n_PickSlipNo INT  
   DECLARE @c_TPickSlipNo NVARCHAR(10)  

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
WHILE @@TRANCOUNT > 0
   COMMIT TRAN

BEGIN TRAN

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

   --tlting01
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   BEGIN TRAN
  
   SET @c_OrderKey = ''   

   INSERT INTO WaveOrderLn (Facility,                     WaveKey,            OrderKey,
                            OrderLineNumber,              Sku,                StorerKey,
                            OpenQty,                      QtyAllocated,       QtyPicked,
                            QtyReplenish,                 UOM,                PackKey,
                            Status,                       Lottable01,         Lottable02,
                            Lottable03,                   Lottable04,         Lottable05,
                            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,   
                            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15   )    
                     SELECT ORDERS.Facility,              WAVEDETAIL.WaveKey, ORDERS.OrderKey,
                            ORDERDETAIL.OrderLineNumber,  ORDERDETAIL.Sku,    ORDERDETAIL.StorerKey,
                            (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked),
                            0,                            0,
                            0,                            ORDERDETAIL.UOM,             ORDERDETAIL.PackKey,
                            ORDERDETAIL.Status,           ORDERDETAIL.Lottable01,      ISNULL(ORDERDETAIL.Lottable02,''),
                            ISNULL(ORDERDETAIL.Lottable03,''),   ORDERDETAIL.Lottable04,  ORDERDETAIL.Lottable05
                           , ISNULL(ORDERDETAIL.Lottable06,'')  
                           , ISNULL(ORDERDETAIL.Lottable07,'')  
                           , ISNULL(ORDERDETAIL.Lottable08,'')  
                           , ISNULL(ORDERDETAIL.Lottable09,'')  
                           , ISNULL(ORDERDETAIL.Lottable10,'')  
                           , ISNULL(ORDERDETAIL.Lottable11,'')  
                           , ISNULL(ORDERDETAIL.Lottable12,'')  
                           , ORDERDETAIL.Lottable13  
                           , ORDERDETAIL.Lottable14  
                           , ORDERDETAIL.Lottable15                                  
   FROM  WAVEDETAIL (NOLOCK)
   JOIN  ORDERS WITH(NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)  --GOH01  
   JOIN  ORDERDETAIL WITH(NOLOCK) ON (ORDERDETAIL.OrderKey = WAVEDETAIL.OrderKey AND ORDERDETAIL.OrderKey = ORDERS.OrderKey)  --GOH01  
   WHERE WAVEDETAIL.WaveKey = @c_WaveKey
   AND   ORDERS.Status <> '9'
   AND   ORDERS.Type NOT IN ('M', 'I')
   AND   OrderDetail.OpenQty - ( OrderDetail.QtyAllocated + OrderDetail.QtyPreAllocated + OrderDetail.QtyPicked) > 0

   -- Loop 1 Lottable01
   IF (@b_debug = 1 or @b_debug = 2)
   BEGIN
      Print 'Start Allocate Full Carton (UCC)..'
   END
      
   DECLARE CUR_WaveDet_Lottable01 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Distinct Lottable01
      FROM  WaveOrderLn (NOLOCK)
      WHERE WaveOrderLn.WaveKey = @c_WaveKey   
      ORDER BY Lottable01

   OPEN CUR_WaveDet_Lottable01
   
   FETCH NEXT FROM CUR_WaveDet_Lottable01 INTO @c_Lottable01 
   WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
   BEGIN

      --IF @@ROWCOUNT = 0
      --   BREAK

		  SELECT @c_PrevOrderKey = ''
      SELECT @c_OrderLineIdx = ''
		  SELECT @n_Carton = 0
		  SELECT @c_Pickslipno = ''

      DECLARE CUR_WaveDetLn CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WaveOrderLn.OrderKey,  WaveOrderLn.OrderLineNumber
      FROM   WaveOrderLn (NOLOCK)
      WHERE  WaveKey = @c_WaveKey
      AND    Lottable01 = @c_Lottable01
      ORDER BY WaveOrderLn.OrderKey,  WaveOrderLn.OrderLineNumber      
            
      OPEN CUR_WaveDetLn 
      
      FETCH NEXT FROM CUR_WaveDetLn INTO @c_OrderKey, @c_OrderLineNumber      
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
      BEGIN

         --tlting01
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN

         BEGIN TRAN      
			-- (START) HK MANUAL ORDER INTERFACE
			IF @c_PrevOrderKey <> @c_OrderKey
			BEGIN
				SELECT @c_StorerKey = StorerKey,
						@cZipCodeTo = ZipCodeTo,
						@c_country = RTRIM(ORDERS.C_Country)
			   FROM ORDERS (NOLOCK)	LEFT OUTER JOIN ROUTEMASTER (NOLOCK)
					ON ORDERS.Route = ROUTEMASTER.Route
			   WHERE OrderKey = @c_OrderKey

   			IF EXISTS(SELECT 1 
							 FROM StorerConfig (NOLOCK)
							 WHERE ConfigKey = 'TBLHK_MANUALORD' And sValue = '1'
             			 AND StorerKey = @c_StorerKey)
             	       AND ISNULL(@cZipCodeTo,'') <> 'EXP'
					       AND @c_country IN('HK','MO') --279705
				BEGIN
					IF NOT EXISTS (SELECT 1 FROM Transmitlog (NOLOCK) WHERE TableName = 'NIKEHKMORD' AND Key1 = @c_OrderKey)     -- 21/11/03
			      BEGIN
			         SELECT @cTransmitlogkey=''
			         SELECT @b_success=1

			         EXECUTE nspg_getkey
			         'TransmitlogKey'
			         ,10
			         , @cTransmitlogKey OUTPUT
			         , @b_success OUTPUT
			         , @n_err OUTPUT
			         , @c_errmsg OUTPUT
			         IF NOT @b_success=1
			         BEGIN
			            SELECT @n_continue=3
			            SELECT @n_err = @@ERROR
			            SELECT @c_errMsg = 'Error Found When Generating TransmitLogKey (ispWRUCC01)'
			         END
			         ELSE
			         BEGIN
			            INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3)
			            VALUES (@cTransmitlogKey, 'NIKEHKMORD', @c_OrderKey, '', @c_StorerKey )

			            IF @@ERROR <> 0
			            BEGIN
			               SELECT @n_continue=3
			               SELECT @n_err = @@ERROR
			               SELECT @c_errMsg = 'Insert into TransmitLog Failed (ispWRUCC01)'
			            END
			         END
			      END
				END								
			END
			-- (END) HK MANUAL ORDER INTERFACE
			
			--279705 start
			
	    IF @c_PrevOrderkey <> @c_Orderkey
	    BEGIN	    	    
	    	    SELECT @c_Pickslipno = ''
	    	    
	    	    SELECT @c_Pickslipno = Pickheaderkey 
	    	    FROM PICKHEADER (NOLOCK)
	    	    WHERE Orderkey = @c_Orderkey
	    	   	    	   
           IF ISNULL(@c_PickslipNo,'') = ''
           BEGIN
               --SELECT @c_PickSlipNo = PickSlipNo
               --FROM PackHeader (NOLOCK)
               --WHERE  OrderKey = @c_OrderKey

               --IF ISNULL(@c_PickslipNo,'') = ''
               --BEGIN
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
   	     		   --END
   	     	  
		          INSERT PickHeader (Pickheaderkey, Wavekey, Orderkey, zone, picktype)
   	     	     VALUES (@c_PickSlipNo, @c_Wavekey, @c_Orderkey, '3','0')   	 
   	     	  END   		
   	     	  
   	     	  IF NOT EXISTS(SELECT 1 FROM PackHeader (NOLOCK)
                          WHERE  OrderKey = @c_OrderKey)
            BEGIN              

   	     	    INSERT PackHeader (PickSlipNo, StorerKey, OrderKey, OrderRefNo, ConsigneeKey, Loadkey, Route)
   					  SELECT @c_PickSlipNo, StorerKey, OrderKey, ExternOrderKey, ConsigneeKey, @c_WaveKey, Route
   					  FROM ORDERS (NOLOCK)
   					  WHERE OrderKey = @c_OrderKey
              
              IF @@ERROR <> 0
              BEGIN
                 SELECT @n_continue=3
                 SELECT @n_err = @@ERROR
                 SELECT @c_errMsg = 'Insert into PackHeader Failed (ispWRUCC01)'
                 GOTO RETURN_SP
              END
            END   	     	  	
      END      
 	    --279705 end  

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
                @c_Lottable15Label = SKU.Lottable15Label                   
         FROM WaveOrderLn (NOLOCK)
         JOIN  SKU (NOLOCK) ON (SKU.StorerKey = WaveOrderLn.StorerKey AND SKU.SKU = WaveOrderLn.SKU)
         WHERE OrderKey = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber

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

         SELECT @c_ExecStatement =
            'DECLARE UCCPickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
            'SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCC.Qty ' +
            'FROM UCC (NOLOCK) ' +
            'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
            'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
            'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
				    'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
            'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
            'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
            'LEFT JOIN CODELKUP CL (NOLOCK) ON (CL.LISTNAME = ''VFCOO'' AND LotAttribute.Lottable01 = CL.Code) ' +
            'WHERE UCC.StorerKey = N''' + RTrim(@c_StorerKey) + ''' ' +
            'AND   UCC.SKU = N''' + RTrim(@c_SKU) + ''' ' +
            'AND   UCC.Status BETWEEN ''1'' AND ''2'' ' +
            'AND   UCC.Qty <= ' + CAST(@n_OpenQty as NVARCHAR(10)) + ' ' +
            'AND   UCC.Qty > 0 ' +
            'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
				    'AND	 LOC.LocationType = ''OTHER'' ' +
			    	'AND	 LOC.LocationFlag <> ''HOLD'' ' +
            'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
            'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '

--         IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
--         BEGIN
--            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
--               ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
--         END
         
         IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
         BEGIN
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
               N' AND EXISTS(SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) WHERE clk.LISTNAME = ''VFCOO'' ' + 
               N' AND LotAttribute.Lottable01 = CLK.Code AND CLK.Short = N''' + RTRIM(@c_Lottable01) + ''') ' 
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

         IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
         BEGIN
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
               ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
         END
         ELSE
         BEGIN
            SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
               ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
         END

			IF (@b_debug = 1 or @b_debug = 2)
		   BEGIN
				Print @c_ExecStatement
		   END

         EXEC sp_executesql @c_ExecStatement

			OPEN UCCPickCursor

			--IF (@@CURSOR_ROWS > 0) AND (@c_PrevOrderKey <> @c_OrderKey)			
      IF (@c_PrevOrderKey <> @c_OrderKey)
			BEGIN
            IF NOT EXISTS(SELECT 1 FROM PackHeader (NOLOCK)
                          WHERE  OrderKey = @c_OrderKey)
            BEGIN  				
   				/*
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

   				IF (@b_debug = 1 or @b_debug = 2)
   			   BEGIN
   			      Print 'Insert PackHeader - Full Carton..'
   			   END
   			  
   			  
   			  --279705 start
   			  IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
                    WHERE OrderKey = @c_OrderKey)
          BEGIN
          	 DELETE FROM PickHeader WHERE Orderkey = @c_Orderkey 
          END
          
		      INSERT PickHeader (Pickheaderkey, Wavekey, Orderkey, zone, picktype)
   			  VALUES (@c_PickSlipNo, @c_Wavekey, @c_Orderkey, '3','0')   			
   			  --279705 end  
   			  */

   				INSERT PackHeader (PickSlipNo, StorerKey, OrderKey, OrderRefNo, ConsigneeKey, Loadkey, Route)
   					SELECT @c_PickSlipNo, StorerKey, OrderKey, ExternOrderKey, ConsigneeKey, @c_WaveKey, Route
   					FROM ORDERS (NOLOCK)
   					WHERE OrderKey = @c_OrderKey

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err = @@ERROR
                  SELECT @c_errMsg = 'Insert into PackHeader Failed (ispWRUCC01)'
                  CLOSE UCCPickCursor
                  DEALLOCATE UCCPickCursor
                  GOTO RETURN_SP
               END
            END -- Not exists in PackHeader
            /*ELSE
            BEGIN
               -- SOS# 69809 TBL UCC allocation problem
               SELECT @c_PickSlipNo = PickSlipNo
               FROM PackHeader (NOLOCK)
               WHERE  OrderKey = @c_OrderKey
            END*/
				-- check for existing packdetail for this order and increment cartonno
				/* will be handled by the new nsp_genlabelno
				SELECT @n_Carton = CONVERT(INT,PODUser)
				FROM ORDERS (NOLOCK)
				WHERE OrderKey = @c_OrderKey

				IF @n_Carton IS NULL OR @n_Carton = NULL
					SELECT @n_Carton = 0
				*/
			END

			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err = 16905
			BEGIN
				CLOSE UCCPickCursor
				DEALLOCATE UCCPickCursor
			END
			IF @n_err <> 0
			BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
            GOTO RETURN_SP
			END
			ELSE
			BEGIN
				SELECT @n_CursorOpen = 1
			END

         SELECT @n_QtyLeftToFulfill = @n_OpenQty

         FETCH NEXT FROM UCCPickCursor INTO
            @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty

         WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
         BEGIN
            -- select @c_UCCNo '@c_UCCNo', @c_Lot 'lot', @c_Loc 'loc', @c_ID 'id', @n_UCC_Qty 'qty'
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
					     	SELECT @c_PickDetailKey,       '',        '',                  @c_OrderKey,
                              @c_OrderLineNumber,     @c_LOT,    @c_Storerkey, 	    @c_Sku,
                              @c_PackKey,             '6',       @n_UCC_Qty,          @n_UCC_Qty,
                              @c_Loc,                 @c_ID,     '',                  'FCP',
                              '',                     '',        'N',                 'U',
                              '8',	                   @c_PickSlipNo
					     END
               
      			   IF @b_success = 1
      			   BEGIN
                     -- select @c_Sku '@c_Sku', @c_Loc '@c_Loc', @n_UCC_Qty '@n_UCC_Qty', @c_UCCNo '@c_UCCNo'
               
   					   INSERT INTO PICKDETAIL ( PickDetailKey,  Caseid,        PickHeaderkey,    OrderKey,
                                              OrderLineNumber,  Lot,           Storerkey, 	    Sku,
                                              PackKey,          UOM,           UOMQty,           Qty,
                                              Loc,              ID,            Cartongroup,      Cartontype,
                                              DoReplenish,      replenishzone, docartonize,      Trafficcop,
                                              PickMethod, 		 PickSlipNo,	 WaveKey)
                     VALUES (@c_PickDetailKey,       '',        '',                  @c_OrderKey,
                             @c_OrderLineNumber,     @c_LOT,    @c_Storerkey, 	    @c_Sku,
                             @c_PackKey,             '6',       @n_UCC_Qty,          @n_UCC_Qty,
                             @c_Loc,                 @c_ID,     RIGHT(RTRIM(@c_UCCNo),8),   'FCP',
                             '',                     '',        'N',                 'U',
                             '8',						  @c_PickSlipNo,						 @c_WaveKey)
               
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
                        CLOSE UCCPickCursor
                        DEALLOCATE UCCPickCursor
                        GOTO RETURN_SP
                     END
               
						   -- insert packdetail
						   SELECT @b_success = 0
               
	   				   EXECUTE nsp_GenLabelNo
						   	@c_orderkey
	   				   ,	@c_Storerkey
	   				   ,	@c_LabelNo OUTPUT
						   ,	@n_Carton OUTPUT
						   ,	'2' -- treat as a "close case" transaction
	   				   ,	@b_success OUTPUT
	   				   ,	@n_err OUTPUT
	   				   ,	@c_errmsg OUTPUT
               
						   IF @b_success = 1
						   BEGIN
						   	/* handled inside nsp_genlabelno
						   	SELECT @n_Carton = @n_Carton + 1
               
						   	UPDATE ORDERS
						   	SET TrafficCop = NULL,
						   		PODUser = CONVERT(CHAR(18), @n_Carton)
						   	WHERE OrderKey = @c_OrderKey
               
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63503
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
                           CLOSE UCCPickCursor
                           DEALLOCATE UCCPickCursor
                           GOTO RETURN_SP
               
                        END
						   	*/
						   	INSERT INTO PACKDETAIL (PickSlipNo,	CartonNo,	LabelNo,	LabelLine,	StorerKey,
						   									SKU,			Qty,			RefNo)
						   	VALUES (@c_PickSlipNo,	@n_Carton,	@c_LabelNo,	'00001',	@c_StorerKey,
						   			  @c_Sku,		   @n_UCC_Qty,	@c_UCCNo)
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63504
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT INTO PACKDETAIL Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PickDetail Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
               
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue=3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63506
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
                               RefNo,          Confirmed, ReplenNo,     Wavekey)
                           VALUES (
                               @c_ReplenishmentKey,       @c_TaskId,
                               @c_StorerKey,   @c_SKU,    @c_LOC,       'PICK',
                               @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                               @c_Packkey,     '1',       0,            0,
                               @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey)
               
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
                              CLOSE UCCPickCursor
                              DEALLOCATE UCCPickCursor
                              GOTO RETURN_SP
                           END
                        END
               
               
                        IF @n_UCC_Qty = @n_QtyLeftToFulfill
                        BEGIN
                           DELETE FROM WaveOrderLn with (ROWLOCK) 
                           WHERE OrderKey = @c_OrderKey
                           AND   OrderLineNumber = @c_OrderLineNumber
               
                           SELECT @n_err = @@ERROR
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue=3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63508
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete WaveOrderLn Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63509
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update WaveOrderLn Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
   
            FETCH NEXT FROM UCCPickCursor INTO
               @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
         END -- while  cursor
         CLOSE UCCPickCursor
         DEALLOCATE UCCPickCursor

      FETCH_NEXT_ORDERLINE:
            SELECT @c_PrevOrderKey = @c_OrderKey             
      
         FETCH NEXT FROM CUR_WaveDetLn INTO @c_OrderKey, @c_OrderLineNumber  
      END -- While 2
   
      CLOSE CUR_WaveDetLn
      DEALLOCATE CUR_WaveDetLn

		--SELECT @c_PrevOrderKey = @c_OrderKey
      
      FETCH NEXT FROM CUR_WaveDet_Lottable01 INTO @c_Lottable01 
   END -- While 1
   CLOSE CUR_WaveDet_Lottable01
   DEALLOCATE CUR_WaveDet_Lottable01

   IF @b_debug = 1
   BEGIN
      Print 'End Allocate Full Carton (UCC)..'
      PRint ''
      Print 'Start Dynamic Pick Face Replenishment...'
   END
END

--tlting01
WHILE @@TRANCOUNT > 0
   COMMIT TRAN

BEGIN TRAN

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   -- Dynamic Pick Face Replenishment
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
       Qty          int )

      CREATE TABLE #TempDynamicLoc
         (Rowref       INT IDENTITY(1,1) PRIMARY KEY,
          PutawayZone  NVARCHAR(10),
          LOC          NVARCHAR(10),
          LogicalLoc   NVARCHAR(18),
          Status       NVARCHAR(1) )

      -- SOS69809 Add new column PutawayZone
      INSERT INTO #TempDynamicPick (PutawayZone, StorerKey, SKU, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07,   
                  Lottable08, Lottable09, Lottable10, Lottable11, Lottable12,  Qty)    
      SELECT SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU,    
             WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03, WaveOrderLn.Lottable06, WaveOrderLn.Lottable07,   
             WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12,       
             SUM(WaveOrderLn.OpenQty) as Qty
      FROM  WaveOrderLn (NOLOCK)
      JOIN  SKU (NOLOCK) ON (WaveOrderLn.StorerKey = SKu.StorerKey and WaveOrderLn.SKU = SKU.SKU)
      WHERE WaveOrderLn.WaveKey = @c_WaveKey and WaveOrderLn.OpenQty > 0
      GROUP BY SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01, WaveOrderLn.Lottable02, WaveOrderLn.Lottable03
               , WaveOrderLn.Lottable06, WaveOrderLn.Lottable07,  
               WaveOrderLn.Lottable08, WaveOrderLn.Lottable09, WaveOrderLn.Lottable10, WaveOrderLn.Lottable11, WaveOrderLn.Lottable12    
      ORDER BY SKU.PutawayZone, WaveOrderLn.StorerKey, WaveOrderLn.SKU, WaveOrderLn.Lottable01 DESC

		IF @b_debug = 1
	   BEGIN
	      SELECT '#TempDynamicPick', * FROM #TempDynamicPick
	   END

      SELECT @c_DynamicLocLoop = '0'
      -- SOS69809
      SET @c_PrevPutAwayZone = ''

      INSERT INTO #TempDynamicLoc (PutawayZone, LOC, LogicalLoc, Status)
      SELECT DISTINCT SKU.PutawayZone, LOC.LOC, LOC.LogicalLocation, '0'
      FROM   WaveOrderLn (NOLOCK)
      JOIN   SKU (NOLOCK) ON (WaveOrderLn.StorerKey = SKu.StorerKey and WaveOrderLn.SKU = SKU.SKU)
      JOIN   LOC (NOLOCK) ON (LOC.PutawayZone = SKU.PutawayZone)
      WHERE  WaveKey = @c_WaveKey and OpenQty > 0
      AND    LOC.LocationType = 'DYNAMICPK'
		AND	 LOC.LocationFlag <> 'HOLD'

		IF @b_debug = 1
	   BEGIN
	      SELECT '#TempDynamicLoc', * FROM #TempDynamicLoc
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
                   @c_UOM = PACK.PackUOM3
            FROM #TempDynamicPick
            JOIN  SKU (NOLOCK) ON (SKU.StorerKey = #TempDynamicPick.StorerKey AND SKU.SKU = #TempDynamicPick.SKU)
            JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            WHERE #TempDynamicPick.PickSeq = @n_PickSeq

            -- -- SOS69809
            IF @c_PrevPutAwayZone <> @c_PutawayZone
            BEGIN
               SET @c_DynamicLocLoop = '0'
               SET @c_PrevPutAwayZone = @c_PutawayZone
            END

            SELECT @c_ExecStatement =
               'DECLARE DynPickCursor CURSOR FAST_FORWARD READ_ONLY FOR  ' +
               'SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCC.Qty ' +
               'FROM UCC (NOLOCK) ' +
               'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
               'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
               'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
               'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
               'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
               'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
               'LEFT JOIN CODELKUP CL (NOLOCK) ON (CL.LISTNAME = ''VFCOO'' AND LotAttribute.Lottable01 = CL.Code) ' +
               'WHERE UCC.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
               'AND   UCC.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
				     	 'AND   UCC.Status BETWEEN ''1'' AND ''4'' ' +
				     	 'AND   UCC.Status <> ''3'' ' +
               'AND   UCC.Qty <= ' + RTRIM(CAST(@n_OpenQty as NVARCHAR(10))) + ' ' +
               'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
               'AND   LOC.LocationType = ''OTHER'' ' +
					     'AND	 LOC.LocationFlag <> ''HOLD'' ' +
               'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
               'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '

--            IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
--            BEGIN
--               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
--                  ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
--            END

            IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
            BEGIN  
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +  
                  N' AND EXISTS(SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) WHERE clk.LISTNAME = ''VFCOO'' ' +   
                  N' AND LotAttribute.Lottable01 = CLK.Code AND CLK.Short = N''' + RTRIM(@c_Lottable01) + ''') '   
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

            IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
            BEGIN
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
            END
            ELSE
            BEGIN
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable05,LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
            END

-- 				IF (@b_debug = 1 or @b_debug = 2)
-- 			   BEGIN
-- 					Print @c_ExecStatement
-- 			   END

            EXEC sp_executesql @c_ExecStatement

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
   				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
   				GOTO RETURN_SP
   			END
   			ELSE
   			BEGIN
   				SELECT @n_CursorOpen = 1
   			END

            SELECT @n_QtyLeftToFulfill = @n_OpenQty

            FETCH NEXT FROM DynPickCursor INTO
               @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty

            WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
            BEGIN
               -- select @c_UCCNo '@c_UCCNo', @c_Lot 'lot', @c_Loc 'loc', @c_ID 'id', @n_UCC_Qty 'qty'
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

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63511
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
                     CLOSE DynPickCursor
                     DEALLOCATE DynPickCursor
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
                     CLOSE DynPickCursor
                     DEALLOCATE DynPickCursor
                     GOTO RETURN_SP
                  END
                  ELSE
                  BEGIN
                     SELECT TOP 1 @c_ToLOC = LOC
                     FROM   #TempDynamicLoc
                     WHERE  PutawayZone = @c_PutawayZone
                     AND    #TempDynamicLoc.Status = @c_DynamicLocLoop
                     ORDER BY LogicalLoc, Loc

                     IF RTRIM(@c_ToLOC) IS NULL
                     BEGIN

                        SELECT @c_DynamicLocLoop = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(2) )

                        SELECT TOP 1 @c_ToLOC = LOC
                        FROM   #TempDynamicLoc
                        WHERE  PutawayZone = @c_PutawayZone
                        AND    #TempDynamicLoc.Status = @c_DynamicLocLoop
                        ORDER BY LogicalLoc, Loc

                        IF RTRIM(@c_ToLOC) IS NULL
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = '', @n_err = 63512   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Dynamic Pick Location Not Found or FULL ! (ispWRUCC01)'
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
                            RefNo,          Confirmed, ReplenNo,     WaveKey)
                        VALUES (
                            @c_ReplenishmentKey,       @c_TaskId,
                            @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                            @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
                            @c_Packkey,     '1',       0,            0,
                            @c_UCCNo,       'N',	    @c_WaveKey,   @c_WaveKey )

               			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               			IF @n_err <> 0
               			BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63513   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
                           CLOSE DynPickCursor
                           DEALLOCATE DynPickCursor
                           GOTO RETURN_SP

               			END
                        ELSE
                        BEGIN
                           UPDATE #TempDynamicLoc
                            SET Status = cast( ( cast(@c_DynamicLocLoop as int) + 1 ) as NVARCHAR(2) )
                           WHERE PutawayZone = @c_PutawayZone
                           AND   LOC = @c_ToLOC
                        END
                     END
                  END

                  IF @n_continue=1 OR @n_continue=2
                  BEGIN
                     IF @n_UCC_Qty = @n_QtyLeftToFulfill
                     BEGIN
                        DELETE FROM #TempDynamicPick
                        WHERE #TempDynamicPick.PickSeq = @n_PickSeq

                        --EXEC ispAllocateWaveOrderLn @c_WaveKey, @c_StorerKey, @c_SKU,
                        --     @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_UCC_Qty
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

                        BREAK
                     END -- @n_UCC_Qty = @n_QtyLeftToFulfill
                     ELSE IF @n_UCC_Qty < @n_QtyLeftToFulfill
                     BEGIN
                        UPDATE #TempDynamicPick
                           SET #TempDynamicPick.Qty = #TempDynamicPick.Qty - @n_UCC_Qty
                        WHERE #TempDynamicPick.PickSeq = @n_PickSeq

                        SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_UCC_Qty

                        --EXEC ispAllocateWaveOrderLn @c_WaveKey, @c_StorerKey, @c_SKU,
                        --     @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_UCC_Qty
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

                     END -- IF @n_UCC_Qty < @n_QtyLeftToFulfill
                  END -- @n_UCC_Qty <= @n_QtyLeftToFulfill
                  ELSE
                  BEGIN
                     BREAK
                  END
               END

               FETCH NEXT FROM DynPickCursor INTO
                  @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty
            END -- while  cursor
            CLOSE DynPickCursor
            DEALLOCATE DynPickCursor
         END
      END -- IF EXISTS(SELECT 1 FROM #TempDynamicPick)
   END -- Select OpenQty > 0
END -- @n_continue=1 OR @n_continue=2
-- DROP TABLE #TempDynamicPick
-- Dynamic Pick Allocation Completed
IF @b_debug = 1
BEGIN
	select 'continue value : ', @n_continue
   SELECT * FROM WaveOrderLn
END
IF @b_debug = 1
BEGIN
   Print 'End Dynamic Pick Face Replenishment...'
   PRint ''
   Print 'Start Allocate from Pick Location...'
END

--tlting01
WHILE @@TRANCOUNT > 0
   COMMIT TRAN

BEGIN TRAN

IF @n_continue = 1 OR @n_continue = 2
BEGIN
	SELECT @c_OrderLineIdx = ''
	SELECT @c_PrevOrderkey = '' --279705
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
 	   --279705 end  

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
           @c_Lottable15Label = SKU.Lottable15Label  
	   FROM WaveOrderLn (NOLOCK)
	   JOIN  SKU (NOLOCK) ON (SKU.StorerKey = WaveOrderLn.StorerKey AND SKU.SKU = WaveOrderLn.SKU)
	   WHERE OrderKey = @c_OrderKey
	   AND   OrderLineNumber = @c_OrderLineNumber

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
        'LEFT JOIN CODELKUP CL (NOLOCK) ON (CL.LISTNAME = ''VFCOO'' AND LotAttribute.Lottable01 = CL.Code) ' +
	      'WHERE LotAttribute.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
	      'AND   LotAttribute.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
	      'AND   (SKUxLOC.LocationType IN (''CASE'', ''PICK'') OR LOC.LocationType = ''CASE'' OR LOC.LocationType = ''DYNAMICPK'') ' +
			  'AND	 LOC.LocationFlag <> ''HOLD'' ' +
        'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
	      'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked > 0 '

--	   IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
--	   BEGIN
--	      SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
--	         ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
--	   END

      IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''  
      BEGIN  
         SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +  
            N' AND EXISTS(SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) WHERE clk.LISTNAME = ''VFCOO'' ' +   
            N' AND LotAttribute.Lottable01 = CLK.Code AND CLK.Short = N''' + RTRIM(@c_Lottable01) + ''') '   
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
         
	   IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
	   BEGIN
	      SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
	         ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable02 DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
	   END
	   ELSE
	   BEGIN
	      SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
	         ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable05, SKUxLOC.LocationType, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
	   END

		IF @b_debug = 1
	   BEGIN
	      Print @c_ExecStatement
	   END

	   EXEC sp_executesql @c_ExecStatement

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
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63514   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
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
	      -- select @c_Lot 'lot', @c_Loc 'loc', @c_ID 'id', @n_LOT_Qty 'qty'
	      IF @n_LOT_Qty > 0 AND @n_QtyLeftToFulfill > 0
	      BEGIN
	         -- select @n_QtyLeftToFulfill '@n_QtyLeftToFulfill'

				-- check for country and lottable01
				SELECT TOP 1 @c_COO = CLK.Short 
				FROM LOTATTRIBUTE (NOLOCK) 
            JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'VFCOO' AND LOTATTRIBUTE.Lottable01 = CLK.Code
				WHERE Lot = @c_Lot 

				IF @c_country <> 'TW' and @c_COO = 'AP'
					IF EXISTS (SELECT 1
									FROM UCC U (NOLOCK) 
                           JOIN LOTATTRIBUTE LA (NOLOCK) ON U.Lot = LA.Lot 
                           JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'VFCOO' AND LA.Lottable01 = CLK.Code
									WHERE U.StorerKey = @c_StorerKey
									AND U.Sku = @c_Sku
									AND U.Status BETWEEN '1' AND '2'
									AND U.Qty > 0 -- SOS58839
									AND CLK.Short <> 'AP') -- there are stocks with other COO available
					BEGIN
						FETCH NEXT FROM PickCursor INTO @c_Lot, @c_Loc, @c_ID, @n_LOT_Qty
						CONTINUE
					END

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

          --279705 to comment
					/*SELECT @c_PickSlipNo = ISNULL(MAX(pickslipno), '')
					FROM Pickdetail (NOLOCK) JOIN Loc (NOLOCK)
						ON Pickdetail.Loc = Loc.Loc
					WHERE Pickdetail.Orderkey = @c_OrderKey
						AND Loc.Putawayzone = @c_Zone*/

               -- select @c_Sku '@c_Sku', @c_Loc '@c_Loc', @n_AllocateQty '@n_AllocateQty'

					INSERT INTO PICKDETAIL ( PickDetailKey,    Caseid,        PickHeaderkey,    OrderKey,
	                                     OrderLineNumber,  Lot,           Storerkey, 	    Sku,
	                                     PackKey,          UOM,           UOMQty,           Qty,
	                                     Loc,              ID,            Cartongroup,      Cartontype,
	                                     DoReplenish,      replenishzone, docartonize,      Trafficcop,
	                                     PickMethod,		 PickSlipNo,    WaveKey)
	            VALUES (@c_PickDetailKey,       '',        '',                  @c_OrderKey,
	                    @c_OrderLineNumber,     @c_LOT,    @c_Storerkey, 	    @c_Sku,
	                    @c_PackKey,             '6',       @n_AllocateQty,      @n_AllocateQty,
	                    @c_Loc,                 @c_ID,     '',                  'PP',
	                    '',                     '',        'N',                 'U',
	                    '8',						  @c_PickSlipNo,						 @c_WaveKey)

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
	                  DELETE FROM WaveOrderLn  WITH(ROWLOCK) 
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

--tlting01
WHILE @@TRANCOUNT > 0
   COMMIT TRAN

BEGIN TRAN

IF @b_debug = 1
BEGIN
   Print 'End Allocate from Pick Location...'
   PRint ''
   Print 'Start Replenisment from Bulk to Pick Loc...'
END
-- complete Pick Location allocation
-- if still have outstanding.....
-- Create replenishment...
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
       Qty          int )

      CREATE TABLE #TempPickLoc
         (ROWref      INT IDENTITY(1,1) PRIMARY KEY,
          StorerKey    NVARCHAR(15),
          Sku			  NVARCHAR(20),
			 LOC          NVARCHAR(10),
          Status       NVARCHAR(1) )

      INSERT INTO #TempReplen (StorerKey, SKU, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07,   
            Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Qty)    
      SELECT StorerKey, SKU, Lottable01, Lottable02, Lottable03, Lottable06, Lottable07,   
            Lottable08, Lottable09, Lottable10, Lottable11, Lottable12,        
            SUM(OpenQty) as Qty
      FROM  WaveOrderLn (NOLOCK)
      WHERE  WaveKey = @c_WaveKey AND OpenQty > 0
      GROUP BY StorerKey, SKU, Lottable01, Lottable02, Lottable03,
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12            
      ORDER BY StorerKey, SKU, Lottable01

		IF (@b_debug = 1 or @b_debug = 2)
	   BEGIN
			SELECT '#TempReplen', * FROM #TempReplen (NOLOCK)
	   END

      INSERT INTO #TempPickLoc (Storerkey, Sku, LOC, Status)
      SELECT DISTINCT SKUXLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.LOC, '0'
      FROM   WaveOrderLn (NOLOCK)
      JOIN   SKUxLOC (NOLOCK) ON (WaveOrderLn.StorerKey = SKUxLOC.StorerKey AND WaveOrderLn.SKU = SKUxLOC.SKU)
      WHERE  WaveKey = @c_WaveKey and OpenQty > 0
      AND    SKUxLOC.LocationType IN ('PICK', 'CASE')

		IF (@b_debug = 1 or @b_debug = 2)
	   BEGIN
			SELECT '#TempPickLoc', * FROM #TempPickLoc (NOLOCK)
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
                   @c_UOM = PACK.PackUOM3
            FROM #TempReplen
            JOIN  SKU (NOLOCK) ON (SKU.StorerKey = #TempReplen.StorerKey AND SKU.SKU = #TempReplen.SKU)
            JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            WHERE #TempReplen.PickSeq = @n_PickSeq

            SELECT @c_ExecStatement =
               'DECLARE PickCursor CURSOR READ_ONLY FOR  ' +
               'SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCC.Qty, LotAttribute.Lottable01 ' +
               'FROM UCC (NOLOCK) ' +
               'JOIN LotAttribute (NOLOCK) ON (UCC.LOT = LotAttribute.LOT) ' +
               'JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.StorerKey = UCC.StorerKey AND SKUxLOC.SKU = UCC.SKU AND SKUxLOC.LOC = UCC.Loc) ' +
               'JOIN LOTxLOCxID (NOLOCK) ON (UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOTxLOCxID.LOC AND UCC.ID = LOTxLOCxID.ID) ' +
               'JOIN LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC) ' +
               'JOIN LOT (NOLOCK) ON (LOT.LOT = LOTxLOCxID.LOT) ' +
               'JOIN ID  (NOLOCK) ON (ID.ID = LOTxLOCxID.ID) ' +
               'LEFT JOIN CODELKUP CL (NOLOCK) ON (CL.LISTNAME = ''VFCOO'' AND LotAttribute.Lottable01 = CL.Code) ' +
               'WHERE UCC.StorerKey = N''' + RTRIM(@c_StorerKey) + ''' ' +
               'AND   UCC.SKU = N''' + RTRIM(@c_SKU) + ''' ' +
               'AND   UCC.Status BETWEEN ''1'' AND ''4'' ' +
							 'AND   UCC.Status <> ''3'' ' +
               'AND   UCC.Qty > 0 ' +
               'AND   SKUxLOC.LocationType NOT IN (''CASE'', ''PICK'') ' +
               'AND   LOC.LocationType = ''OTHER'' ' +
               'AND	 LOC.LocationFlag <> ''HOLD'' ' +
               'AND   LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' +
               'AND   LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked >= UCC.Qty '

--            IF RTRIM(@c_Lottable01) IS NOT NULL AND RTRIM(@c_Lottable01) <> ''
--            BEGIN
--               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
--                  ' AND LotAttribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' '
--            END

            IF RTRIM(ISNULL(@c_Lottable01,'')) <> ''
            BEGIN
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  N' AND EXISTS(SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) WHERE clk.LISTNAME = ''VFCOO'' ' + 
                  N' AND LotAttribute.Lottable01 = CLK.Code AND CLK.Short = N''' + RTRIM(@c_Lottable01) + ''') ' 
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

            IF RTRIM(@c_Lottable02Label) IS NOT NULL AND RTRIM(@c_Lottable02Label) <> ''
            BEGIN
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable02, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
            END
            ELSE
            BEGIN
               SELECT @c_ExecStatement = RTRIM(@c_ExecStatement) +
                  ' ORDER By ISNULL(CL.Short,'''') DESC, LotAttribute.Lottable05, LOC.LogicalLocation, SKUxLOC.Loc, LOTxLOCxID.ID '
            END

				IF @b_debug = 1
			   BEGIN
			      Print @c_ExecStatement
			   END

            EXEC sp_executesql @c_ExecStatement

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
   				SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Creation/Opening of Candidate Cursor Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
   			END
   			ELSE
   			BEGIN
   				SELECT @n_CursorOpen = 1
   			END

-- 				IF @@CURSOR_ROWS = 0
-- 				BEGIN
-- 					CLOSE PickCursor
--    				DEALLOCATE PickCursor
-- 					CONTINUE
-- 				END

            SELECT @n_QtyLeftToFulfill = @n_OpenQty

            FETCH NEXT FROM PickCursor INTO
               @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty, @c_SysLottable01

            WHILE @@FETCH_STATUS <> -1 AND (@n_continue=1 OR @n_continue=2)
            BEGIN
               -- select @c_UCCNo '@c_UCCNo', @c_Lot 'lot', @c_Loc 'loc', @c_ID 'id', @n_UCC_Qty 'qty',
                  -- @n_UCC_Qty '@n_UCC_Qty', @n_QtyLeftToFulfill  '@n_QtyLeftToFulfill'

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
                     SET @c_COO = ''
                      
				             SELECT TOP 1 @c_COO = CLK.Short 
				             FROM LOTATTRIBUTE (NOLOCK) 
                         JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'VFCOO' AND LOTATTRIBUTE.Lottable01 = CLK.Code
				             WHERE Lot = @c_Lot 
                         
                     SET @c_ToLOC = ''
							       IF @c_COO > ''
							       BEGIN -- look for pick loc with the same COO lottable01 with qty > 0
                     
							       	  SELECT @c_ToLOC = MIN(#TempPickLoc.LOC)
	                              FROM   #TempPickLoc 
                                 JOIN LOTxLOCxID (NOLOCK)  ON  #TempPickLoc.Loc = LOTxLOCxID.Loc 
                                                           AND #TempPickLoc.StorerKey = LOTxLOCxID.StorerKey
							       	                            AND #TempPickLoc.Sku = LOTxLOCxID.Sku
							       	  			                 AND LOTxLOCxID.Qty > 0
                                 JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = LOTxLOCxID.Lot 
	                              WHERE  #TempPickLoc.Status = '0'
							       	  AND	 #TempPickLoc.Sku = @c_sku 
                                 AND    EXISTS(SELECT 1 FROM CODELKUP CLK WITH (NOLOCK) 
                                               WHERE clk.LISTNAME = 'VFCOO' 
                                               AND LA.Lottable01 = CLK.Code 
                                               AND CLK.Short = @c_COO)
                        
							       	  IF ISNULL(RTRIM(@c_ToLOC),'') = '' 
							       	  BEGIN -- look for empty pick loc
							       	  	SELECT @c_ToLOC = MIN(#TempPickLoc.LOC)
		                              FROM   #TempPickLoc JOIN SKUxLOC (NOLOCK)
							       	  		ON #TempPickLoc.Loc = SKUxLOC.Loc
							       	  			AND #TempPickLoc.Sku = SKUxLOC.Sku
							       	  			AND SKUxLOC.Qty = 0
		                              WHERE  #TempPickLoc.Status = '0'
							       	  	AND	 #TempPickLoc.Sku = @c_sku
							       	  END
							       	  
							       	  --279705
							       	  IF ISNULL(RTRIM(@c_ToLOC),'') = ''
							       	  BEGIN
            	       	  	 SELECT @n_continue = 3
            	       	  	 SELECT @c_errmsg = '', @n_err = 63515   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            	       	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Do not merge AP and CN stock in a same pickface. Additional Pickface required. (ispWRUCC01)'
							             BREAK
							       	  END								
							       END
                     
							       IF ISNULL(RTRIM(@c_ToLOC),'') = '' 
							       BEGIN
	                      SELECT @c_ToLOC = MIN(#TempPickLoc.LOC)
	                      FROM   #TempPickLoc
	                      WHERE  #TempPickLoc.Status = '0'
							       	  AND #TempPickLoc.Sku = @c_sku
							       END
                     
                     IF ISNULL(RTRIM(@c_ToLOC),'') = '' 
                     BEGIN
            	       		SELECT @n_continue = 3
            	       		SELECT @c_errmsg = '', @n_err = 63516   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            	       		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Permanent Pick Location Not Found! (ispWRUCC01)'
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
                        
                     		-- Start : SOS38467
                     		IF @n_UCC_Qty < @n_QtyLeftToFulfill
                     			 SELECT @n_QtyInPickLOC = @n_UCC_Qty
                     		ELSE
                     			 SELECT @n_QtyInPickLOC = @n_QtyLeftToFulfill
                     		-- End : SOS38467
                     
                        INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                            StorerKey,      SKU,       FromLOC,      ToLOC,
                            Lot,            Id,        Qty,          UOM,
                            PackKey,        Priority,  QtyMoved,     QtyInPickLOC,
                            RefNo,          Confirmed, ReplenNo,     Wavekey)
                        VALUES (
                            @c_ReplenishmentKey,       @c_TaskId,
                            @c_StorerKey,   @c_SKU,    @c_LOC,       @c_ToLOC,
                            @c_LOT,         @c_ID,     @n_UCC_Qty,   @c_UOM,
							       @c_Packkey,     '1',       0,            @n_QtyInPickLOC,
                            @c_UCCNo,       'N',       @c_WaveKey,   @c_WaveKey)
                     
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                        	  SELECT @n_continue = 3
                        	  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63517   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        	  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (ispWRUCC01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
							          		BREAK
            	          END
                     END
                  END
                  
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
                  BREAK
               END

               FETCH NEXT FROM PickCursor INTO
                  @c_UCCNo, @c_Lot, @c_Loc, @c_ID, @n_UCC_Qty, @c_SysLottable01
            END -- while  cursor
            CLOSE PickCursor
            DEALLOCATE PickCursor
         END
      END -- IF EXISTS(SELECT 1 FROM #TempReplen)
      DROP TABLE #TempReplen
   END -- Select OpenQty > 0
END -- @n_continue=1 OR @n_continue=2
IF @b_debug = 1
BEGIN
   PRint ''
   Print 'End Replenisment from Bulk to Pick Loc...'
END
-- Last Replenishment

-- clean up waveorderln table
DELETE WaveOrderLn WHERE WaveOrderLn.WaveKey = @c_WaveKey

   
WHILE @@TRANCOUNT > 0
   COMMIT TRAN
   
RETURN_SP:

--tlting01
   
WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN TRAN
   
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
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
	execute nsp_logerror @n_err, @c_errmsg, 'ispWRUCC01'
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


GO