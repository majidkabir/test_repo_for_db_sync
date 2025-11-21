SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Allocation_Wrapper                             */  
/* Creation Date: 29-Jan-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Allocation from Shipment Order, Load Plan or Wave           */  
/*                                                                      */  
/* Called By: Allocation                                                */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */
/* 2020-11-23  Wan01    1.1   Add Big Outer Begin Try..End Try to enable*/
/*                            Revert when Sub SP Raise error            */
/* 2021-01-15  Wan02    1.2   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Allocation_Wrapper]
   @c_Orderkey     NVARCHAR(10) = '', -- pass in only if call from shipment order
  @c_Loadkey      NVARCHAR(10) = '', -- pass in only if call from load plan
  @c_Wavekey      NVARCHAR(10) = '', -- pass in only if call from wave
  @b_Success      INT OUTPUT, 
  @n_err          INT OUTPUT,
  @c_ErrMsg       NVARCHAR(215) OUTPUT,
  @c_UserName     NVARCHAR(50) = '',
  @c_AllocateFrom NVARCHAR(10) = ''  --ORDER/LOAD/WAVE  (optional)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue                 INT,
           @c_SQL                      NVARCHAR(MAX),
           @c_Storerkey                NVARCHAR(15),
           @c_Facility                 NVARCHAR(5),
           @c_Type                     NVARCHAR(10),
           @c_Userdefine08             NVARCHAR(10),
           @c_FinalizeLP               NVARCHAR(10),
           @c_LPFinalizeFlag           NCHAR(1),
           @c_SuperOrderFlag           NVARCHAR(1),
           @c_AllowLPAlloc4DiscreteOrd NVARCHAR(10),
           @c_AllocLPOrderByLot02      NVARCHAR(10),
           @c_AllocLPOrdByPriority     NVARCHAR(10),
           @c_extendparms              NVARCHAR(250),
           @c_ValidateCancelDate       NVARCHAR(10), 
           @c_WaveConsoAllocation      NVARCHAR(10),
           @c_LoadConsoAllocation      NVARCHAR(10),
           @c_ContinueAllocUnLoadSO    NVARCHAR(10),
           @c_AllocateMode             NVARCHAR(10),           
           @c_WaveALOrderSort_SP       NVARCHAR(10)

   SELECT @n_continue = 1, @b_Success = 0
   
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    --(Wan02) - END
   
   --(Wan01) - START
   BEGIN TRY
      IF ISNULL(@c_Orderkey,'') = '' AND ISNULL(@c_Loadkey,'') = '' AND ISNULL(@c_Wavekey,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_Err = 550151
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                ': Must provide orderkey or loadkey or wavekey. (lsp_Allocation_Wrapper)'                
         GOTO EXIT_SP       
      END 
   
       CREATE TABLE #TMP_ORDER (Row INT IDENTITY(1,1), Orderkey NVARCHAR(10))       
   
      IF ISNULL(@c_Orderkey,'') <> ''   ----------> Order allocation
      BEGIN           
           IF ISNULL(@c_AllocateFrom,'') = ''
              SET @c_AllocateFrom = 'ORDER'
           
         IF EXISTS(SELECT 1         
                   FROM ORDERDETAIL (NOLOCK)
                   JOIN SKU (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku
                   WHERE ORDERDETAIL.Orderkey = @c_Orderkey
                   AND SKU.Skustatus = 'SUSPENDED')
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_Err = 550152
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                   ': Found Suspended Sku. Allocation failed. (lsp_Allocation_Wrapper)'               
            GOTO EXIT_SP               
         END
      
         IF @c_AllocateFrom = 'LOAD' 
            SET @c_extendparms = 'LP'
         ELSE IF @c_AllocateFrom = 'WAVE'    
            SET @c_extendparms = 'WP'
         ELSE   
            SET @c_extendparms = ''
                     
           EXEC dbo.nsp_orderprocessing_wrapper 
               @c_orderkey = @c_Orderkey,  
               @c_oskey = '', --opkey
               @c_docarton = 'Y',  
               @c_doroute = 'N',   
               @c_tblprefix = '',  --runcode
               @c_extendparms = @c_extendparms        

         SELECT @n_err = @@ERROR
      
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550153   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO EXIT_SP
         END                        
      END 
      ELSE IF ISNULL(@c_Loadkey,'') <> ''  -----------> Load Plan allocation
      BEGIN
           IF ISNULL(@c_AllocateFrom,'') = ''
              SET @c_AllocateFrom = 'LOAD'

         SELECT TOP 1 @c_Storerkey = O.Storerkey,
                      @c_Facility = O.Facility,
                      @c_LPFinalizeFlag = LP.Finalizeflag,
                      @c_SuperOrderFlag = LP.SuperOrderFlag
         FROM LOADPLAN LP (NOLOCK)
         JOIN LOADPLANDETAIL LD (NOLOCK) ON LP.Loadkey = LD.Loadkey 
         JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
         WHERE LP.Loadkey = @c_Loadkey
         
         SELECT @c_FinalizeLP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeLP')
         SELECT @c_ValidateCancelDate = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateCancelDate')
         SELECT @c_AllowLPAlloc4DiscreteOrd = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowLPAlloc4DiscreteOrd') 
         SELECT @c_AllocLPOrderByLot02 = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocLPOrderByLot02') 
         SELECT @c_AllocLPOrdByPriority = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocLPOrdByPriority') 
         SELECT @c_AllowLPAlloc4DiscreteOrd = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowLPAlloc4DiscreteOrd')
      
         /*
         IF @c_FinalizeLP <> '1'
         BEGIN
             IF EXISTS (SELECT 1 
                        FROM LOADPLANDETAIL LD (NOLOCK)
                        JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
                        JOIN STORERCONFIG SC (NOLOCK) ON O.Storerkey = SC.Storerkey
                        WHERE SC.Configkey = 'FinalizeLP'
                        AND SC.Svalue = '1'
                        AND LD.Loadkey = @c_Loadkey)
                SET @c_FinalizeLP = '1'         
         END
         */ 
      
         IF @c_FinalizeLP = '1' AND @c_LPFinalizeFlag <> 'Y'
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_Err = 550154 
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                   ': Please Finalize this Loadplan before proceeding to allocate. (lsp_Allocation_Wrapper)'               
            GOTO EXIT_SP               
         END

         /*
         IF @c_ValidateCancelDate = '1'
         BEGIN
             IF EXISTS (SELECT 1
                        FROM LOADPLANDETAIL (NOLOCK)      
                        JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
                        WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
                        AND ORDERS.DeliveryDate < CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 112)))
             BEGIN
               SELECT @n_continue = 3  
               SELECT @n_Err = 550155 
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                      ': Warning ! Found Order cancel date < Today date. (lsp_Allocation_Wrapper)'                
               GOTO EXIT_SP                           
             END
         END
         */ 
      
         IF @c_SuperOrderFlag = 'Y'
         BEGIN
            EXEC dbo.nsp_orderprocessing_wrapper 
                     @c_orderkey = '',  
                     @c_oskey = @c_Loadkey, --opkey
                     @c_docarton = 'N',  
                     @c_doroute = 'N',   
                     @c_tblprefix = '',  --runcode
                     @c_extendparms = 'LP'
                     --@c_extendparms = ''

            SELECT @n_err = @@ERROR
         
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550156  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO EXIT_SP
            END                                                            
         END                
         ELSE
         BEGIN          
            IF @c_AllocLPOrderByLot02 = '1'
            BEGIN
               SET @c_SQL = 'INSERT INTO #TMP_ORDER (Orderkey)
                             SELECT LPD.OrderKey   
                              FROM LOADPLANDETAIL LPD (NOLOCK)
                              LEFT OUTER JOIN ORDERDETAIL OD (NOLOCK) ON (LPD.OrderKey = OD.OrderKey
                                                                               AND ISNULL(OD.Lottable02,'') <> '')
                              WHERE LPD.LoadKey = @c_Loadkey 
                              GROUP BY LPD.LoadKey, LPD.OrderKey
                              ORDER BY COUNT(OD.Lottable02) DESC '
             END           
             ELSE IF @c_AllocLPOrdByPriority = '1' 
             BEGIN
               SET @c_SQL = 'INSERT INTO #TMP_ORDER (Orderkey)
                             SELECT LPD.OrderKey   
                              FROM LOADPLANDETAIL LPD (NOLOCK)
                              JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
                              WHERE LPD.LoadKey = @c_Loadkey 
                              ORDER BY O.Priority, LPD.LoadLineNumber '             
             END
             ELSE
             BEGIN
               SET @c_SQL = 'INSERT INTO #TMP_ORDER (Orderkey)
                             SELECT LPD.OrderKey   
                              FROM LOADPLANDETAIL LPD (NOLOCK)
                              JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
                              WHERE LPD.LoadKey = @c_Loadkey 
                              ORDER BY LPD.LoadLineNumber '             
             END           
          
            EXEC sp_executesql @c_SQL,
               N'@c_Loadkey NVARCHAR(10)', 
               @c_LoadKey
          
            SELECT @n_err = @@ERROR
         
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550157   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Insert #TMP_ORDER Table Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO EXIT_SP
            END 
         
            DECLARE CUR_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT O.Orderkey, 
                      O.type, 
                      O.Userdefine08  --Discrete order
               FROM #TMP_ORDER  
               JOIN ORDERS O (NOLOCK) ON #TMP_ORDER.Orderkey = O.Orderkey  
               ORDER BY #TMP_ORDER.Row
         
            OPEN CUR_Order  
         
            FETCH NEXT FROM CUR_Order INTO @c_Orderkey, @c_Type, @c_Userdefine08
         
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
            BEGIN            
                 IF @c_AllowLPAlloc4DiscreteOrd = '1'
                 BEGIN
                    EXEC dbo.nsp_orderprocessing_wrapper 
                        @c_orderkey = @c_Orderkey,  
                        @c_oskey = '', --opkey
                        @c_docarton = 'N',  
                        @c_doroute = 'N',   
                        @c_tblprefix = '',  --runcode
                        @c_extendparms = 'LP'                        
                 END
                 ELSE
                 BEGIN
                   IF @c_Type NOT IN('I','M') AND @c_Userdefine08 <> 'Y'
                   BEGIN
                       EXEC dbo.nsp_orderprocessing_wrapper 
                           @c_orderkey = @c_Orderkey,  
                           @c_oskey = '', --opkey
                           @c_docarton = 'N',  
                           @c_doroute = 'N',   
                           @c_tblprefix = '',  --runcode
                           @c_extendparms = 'LP'                        
                   END
                 END

               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550158  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                                                            
                                      
               FETCH NEXT FROM CUR_Order INTO @c_Orderkey, @c_Type, @c_Userdefine08
            END
            CLOSE CUR_Order
            DEALLOCATE CUR_Order                  
         END                    
      END
      ELSE IF ISNULL(@c_Wavekey,'') <> ''  ----------> Wave allocation
      BEGIN
          IF ISNULL(@c_AllocateFrom,'') = ''
              SET @c_AllocateFrom = 'WAVE'
           
           SELECT TOP 1 @c_Storerkey = O.Storerkey,
                @c_Facility = O.Facility
         FROM WAVE W (NOLOCK)
         JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey 
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         WHERE W.Wavekey = @c_Wavekey
         
         SELECT @c_ValidateCancelDate = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ValidateCancelDate')
         SELECT @c_WaveConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveConsoAllocation')
         SELECT @c_LoadConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadConsoAllocation')
         SELECT @c_ContinueAllocUnLoadSO = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ContinueAllocUnLoadSO')
         SELECT @c_WaveALOrderSort_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveALOrderSort_SP')
      
         /*
         IF @c_ValidateCancelDate = '1'
         BEGIN
             IF EXISTS (SELECT 1
                        FROM WAVEDETAIL (NOLOCK)       
                        JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
                        WHERE WAVEDETAIL.Wavekey = @c_Wavekey
                        AND ORDERS.DeliveryDate < CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 112)))
             BEGIN
               SELECT @n_continue = 3  
               SELECT @n_Err = 550159 
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                      ': Warning ! Found Order cancel date < Today date. (lsp_Allocation_Wrapper)'                
               GOTO EXIT_SP                           
             END
         END
         */ 
      
         EXEC dbo.isp_WaveCheckAllocateMode_Wrapper 
            @c_Wavekey = @c_Wavekey,
            @c_AllocateMode = @c_AllocateMode OUTPUT,
            @b_Success = @b_Success OUTPUT,
            @n_Err = @n_Err OUTPUT,
            @c_ErrMsg = @c_ErrMsg OUTPUT
      
         IF (@c_WaveConsoAllocation  = '1' OR @c_AllocateMode = '#WC') AND @c_AllocateMode NOT IN('#DC','#LC')  --Wave conso allocation
         BEGIN
             EXEC dbo.ispWaveProcessing 
                @c_Wavekey = @c_Wavekey, 
               @b_Success = @b_Success OUTPUT,
               @n_Err = @n_Err OUTPUT,
               @c_ErrMsg = @c_ErrMsg OUTPUT                   
         
            IF @b_Success <> 1
            BEGIN
               SET @n_continue = 3
               GOTO EXIT_SP
            END            
         END      
         ELSE IF @c_LoadConsoAllocation = '1' AND @c_AllocateMode <> '#DC'  --Wave's load conso allocation
         BEGIN
             IF @c_ContinueAllocUnLoadSO <> '1'
             BEGIN
                 SET @c_Orderkey = ''
                SELECT TOP 1 @c_Orderkey = ORDERS.Orderkey 
               FROM WAVEDETAIL (NOLOCK)
               JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey 
               LEFT JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey 
               WHERE ISNULL(LOADPLANDETAIL.Orderkey,'')=''  
               AND WAVEDETAIL.Wavekey = @c_Wavekey 
                ORDER BY WAVEDETAIL.Orderkey
             
                IF ISNULL(@c_Orderkey,'') <> ''
                BEGIN
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 550160 
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                         ': All ordres belong to Wave Wave# '+ RTRIM(@c_Wavekey) + ' . must be populated to Load Plan Before Allocation. Order# ' + RTRIM(@c_Orderkey) + ' (lsp_Allocation_Wrapper)'
                  GOTO EXIT_SP                                       
                END             
             END
          
            DECLARE CUR_Load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                 SELECT DISTINCT LOADPLANDETAIL.Loadkey 
                  FROM WAVEDETAIL (NOLOCK)       
                  JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
                  JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey
                  WHERE WAVEDETAIL.Wavekey = @c_Wavekey
                  ORDER BY LOADPLANDETAIL.Loadkey   
                     
            OPEN CUR_Load  
         
            FETCH NEXT FROM CUR_Order INTO @c_Loadkey
        
            IF @@FETCH_STATUS = 0 
            BEGIN
               SELECT @n_continue = 3  
               SELECT @n_Err = 550166
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                      ': No Load Plan Found For Wave# '+ @c_Wavekey + '. Please Create Load Before Wave Allocation. (lsp_Allocation_Wrapper)'               
            END
         
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
            BEGIN
               EXEC dbo.nsp_orderprocessing_wrapper 
                     @c_orderkey = '',  
                     @c_oskey = @c_Loadkey, --opkey
                     @c_docarton = 'N',  
                     @c_doroute = 'N',   
                     @c_tblprefix = '',  --runcode
                     @c_extendparms = 'WP'                  

               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550161  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                                                            
            
               FETCH NEXT FROM CUR_Order INTO @c_Loadkey
            END
            CLOSE CUR_Load
            DEALLOCATE CUR_Load           
         
            --Allocate remaining orders without loadplan
            DECLARE CUR_nonLoadorder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT WAVEDETAIL.Orderkey
                FROM WAVEDETAIL WITH (NOLOCK)
                WHERE WAVEDETAIL.Wavekey = @c_Wavekey
                    AND NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE Orderkey = WAVEDETAIL.Orderkey)

            OPEN CUR_nonLoadorder  
         
            FETCH NEXT FROM CUR_nonLoadorder INTO @c_Orderkey

            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
            BEGIN
               EXEC dbo.nsp_orderprocessing_wrapper 
                      @c_orderkey = @c_Orderkey,  
                      @c_oskey = '', --opkey
                      @c_docarton = 'N',  
                      @c_doroute = 'N',   
                      @c_tblprefix = '',  --runcode
                      @c_extendparms = 'WP'                 

               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550162   
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                                                            
             
               FETCH NEXT FROM CUR_nonLoadorder INTO @c_Orderkey
            END
            CLOSE CUR_nonLoadorder
            DEALLOCATE CUR_nonLoadorder                      
         END
         ELSE
         BEGIN --Wave discrete allocation
            IF EXISTS(SELECT 1 FROM dbo.SysObjects O WITH (NOLOCK)
                      WHERE Name = @c_WaveALOrderSort_SP
                      AND Type = 'P') AND ISNULL(@c_WaveALOrderSort_SP,'') <> ''
            BEGIN
                 --Get allocation sorting from custom stored proc
                 SET @c_SQL  = 'INSERT INTO #TMP_ORDER (Orderkey)
                                EXEC ' + RTRIM(@c_WaveALOrderSort_SP) +  ' @c_Wavekey = @c_WavekeyP'             
                                            
               EXEC sp_executesql @c_SQL,
                  N'@c_wavekeyP NVARCHAR(10)', 
                  @c_Wavekey
             
               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550163
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Insert #TMP_ORDER Table Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO EXIT_SP
               END                                                        
            END          
            ELSE
            BEGIN
               SET @c_SQL = 'INSERT INTO #TMP_ORDER (Orderkey)
                             SELECT WD.OrderKey   
                              FROM WAVEDETAIL WD (NOLOCK)
                              JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                              WHERE WD.WaveKey = @c_Wavekey 
                              ORDER BY WD.Orderkey '              

               EXEC sp_executesql @c_SQL,
                  N'@c_Wavekey NVARCHAR(10)', 
                  @c_WaveKey
             
               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550164
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Insert #TMP_ORDER Table Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO EXIT_SP
               END            
            END         
                
            DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT Orderkey
               FROM #TMP_ORDER  
               ORDER BY Row
         
            OPEN CUR_WaveOrder  
         
            FETCH NEXT FROM CUR_WaveOrder INTO @c_Orderkey
         
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
            BEGIN            
               EXEC dbo.nsp_orderprocessing_wrapper 
                      @c_orderkey = @c_Orderkey,  
                      @c_oskey = '', --opkey
                      @c_docarton = 'Y',  
                      @c_doroute = 'N',   
                      @c_tblprefix = '',  --runcode
                      @c_extendparms = 'WP'
                                    
               SELECT @n_err = @@ERROR
            
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 550165
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Execute nsp_orderprocessing_wrapper Failed. (lsp_Allocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                                                            
              
               FETCH NEXT FROM CUR_WaveOrder INTO @c_Orderkey
            END
            CLOSE CUR_WaveOrder
            DEALLOCATE CUR_WaveOrder                                                        
         END                    
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Allocation fail. (lsp_Allocation_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH             
   --(Wan01) - END

   EXIT_SP:
   --(Wan01) - START
   IF @n_continue <> 3 
   BEGIN
      SET @b_success = 1
   END
   ELSE
   BEGIN       
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Allocation_Wrapper'  
   END
   --(Wan01) - END
   REVERT 
END  

GO