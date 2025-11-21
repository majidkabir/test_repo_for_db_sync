SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/ 
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.5                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications: Made a copy from ntrTransmitLogUpdate.              */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 06-Nov-2002  Leo Ng    1.0   Program rewrite for IDS version 5          */  
/* 26-Jul-2004  Shong     1.0   - Customize the Full Carton allocation     */  
/*                              For Consolidated Orders for 1 Load Plan.   */  
/*                              (SOS# 25496)                               */  
/* 21-Jul-2007  Shong     1.0   - Customization for US project, handling   */  
/*                              Pre-Pack Allocation.                       */  
/* 15-Aug-2008  TLTING    1.1   Version Sync with US (tlting01)            */   
/* 13-Oct-2009  Shong     1.3   - Added New Allocation For Load            */
/*                              Consolidation Allocation                   */
/* 07-Jun-2010  Shong     1.4   - Capture allocation shortage after        */
/*                              allocation.                                */
/* 29-Dec-2010  YokeBeen  1.5   SOS#198768 - Changed key values for table  */
/*                              TransmitLog of Tablename = "ORDALLOC".     */
/*                              - (YokeBeen01)                             */
/* 08-Nov-2013  Shong     1.6  Insert TraceInfo when Flag ON               */ 
/* 13-Nov-2013  Shong     1.7  Add Post SP Execution base on StorerConfig  */
/* 27-Nov-2013  YTWan     1.8  SOS#293830:LP allocation by default         */
/*                             strategykey (Wan01)                         */
/* 23-Apr-2014  NJOW      1.9  306662-Pre-allocation process calling       */
/*                             custom SP                                   */
/* 19-Feb-2014  Chee      2.0  - Add storerKey to                          */
/*                               nspGetRight - ALLOW ALLOCATION            */
/*                             - Change ALLOW ALLOCATION to                */
/*                               CheckManualAlloc (Chee01)                 */
/* 29-Sep-2014  NJOW02    2.1  306662-Change PostAllocationSP support      */
/*                             allocation strategykey pickcode setup       */
/* 28-Jan-2015  NJOW03    2.2  330996-OTM Plan Mode Allocation Checking    */
/* 25-Aug-2015  SHONG01   2.3  Enforce Allocation Policy for China Double  */
/*                             Eleven Event                                */
/* 07-Oct-2015  NJOW04    2.4  353920 - Allocation extended validation     */
/* 27-Oct-2015  NJOW05    2.5  355392 - Storerconfig support by facility   */
/* 04-Oct-2016  TLTING01  2.6  Performance Tune                            */
/* 11-Oct-2016  SHONG     2.7  Check ECOM Skip Preallocation Strategy if   */
/*                             Checking flag turn on                       */
/* 19-Jul-2018  NJOW06    2.8  WMS-5745 Standard Pre/Post allocation process*/
/* 08-Jan-2020  NJOW07    2.9  WMS-10420 add strategykey parameter         */
/* 15-May-2024  NJOW08    3.0  WMS-25272 if PreRunStrategykey skip execute */
/*                             pre/post                                    */
/* 24-May-2024  NJOW09    3.1  UWP-18748 UK Demeter enable configure allocate*/
/*                             strategy to PreAllocationSP                 */ 
/***************************************************************************/    
CREATE   PROCEDURE [dbo].[nsp_OrderProcessing_Wrapper]  
                  @c_OrderKey NVARCHAR(10) ,  
                  @c_oskey NVARCHAR(10) ,  
                  @c_docarton CHAR (1),  
                  @c_doroute  CHAR (1),  
                  @c_tblprefix CHAR (3),
                  @c_extendparms NVARCHAR(250) = '',   --(Wan01)  
                  @c_StrategykeyParm NVARCHAR(10) = '' --NJOW07
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @i_Success       INTEGER,  
           @i_error         INTEGER,  
           @c_errmsg        NVARCHAR(255),   
           @b_AllowAllocate INT,
           @c_SuperOrderFlag NVARCHAR(1),
           @n_ConsoCaseAlloc INT,
           @c_Facility NVARCHAR(5),
           @c_LoadPlanDynamicAllocByUCC NVARCHAR(1), -- CN NIKE Bridge
           @n_LoadConsoAllocation INT,           
           @n_PrePackAlloc     INT, 
           @c_StorerKey        NVARCHAR(15), 
           @c_PostAllocationSP NVARCHAR(200),    
           @c_PreAllocationSP  NVARCHAR(200), --NJOW       
           @c_LoadKey          NVARCHAR(10),   --SHONG01
           @c_SQL              NVARCHAR(2000), --NJOW04
           @c_AllocateValidationRules  NVARCHAR(30), --NJOW04
           @c_PreRunStrategykey        NVARCHAR(10) = '', --NJOW08
           @b_debug            INT
           
   SELECT @b_AllowAllocate  = 1  
   SELECT @c_SuperOrderFlag = ''
   SELECT @n_ConsoCaseAlloc = 0
   SELECT @n_PrePackAlloc   = 0
   SELECT @c_Facility       = ''   
   SELECT @c_LoadPlanDynamicAllocByUCC = ''
   SET    @n_LoadConsoAllocation = 0
   SET    @c_LoadKey = ''
   
   IF @c_tblprefix = '1'
   BEGIN
      SET @b_debug = 1
      SET @c_tblprefix = 'DS1'
   END
   ELSE
   BEGIN
      SET @b_debug = 0
   END

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
        
   -- Move up from bottom (Chee01)
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
   BEGIN
      SELECT @c_StorerKey = StorerKey, 
             @c_Facility  = o.Facility, -- SHONG01 
             @c_LoadKey   = o.LoadKey   -- SHONG01 
      FROM   ORDERS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_OrderKey            
   END 
   ELSE
   BEGIN
      SET @c_LoadKey = @c_oskey -- SHONG01 
      
      SELECT TOP 1 
             @c_StorerKey = o.StorerKey, 
             @c_Facility  = o.Facility -- SHONG01                
      FROM   ORDERS o WITH (NOLOCK) 
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey
      WHERE lpd.LoadKey = @c_oskey            
   END  
   
   -- SHONG01 SOS#349953 (Start)
   DECLARE @c_DisableAllocationFlag CHAR(1), -- Allocate Flag (1-Disable, 0-Enable) 
           @c_AllocationType        NVARCHAR(10),   -- Allocate type (BATCH-Batch allocate, Null-Order Allocate)
           @n_RecordFound           INT, 
           @c_LoadDefaultStrategy   CHAR(1), 
           @c_SKUStrategy           NVARCHAR(10),
           @c_StorerStrategy        NVARCHAR(10), 
           @c_ValidStrategy01       NVARCHAR(10),
           @c_ValidStrategy02       NVARCHAR(10),
           @c_ValidStrategy03       NVARCHAR(10), 
           @c_SkipPreAllocFlag      NVARCHAR(10), 
           @c_CheckSkipPrAllStrg    NVARCHAR(10) 
   
   SET @n_RecordFound = 0 
   SET @c_DisableAllocationFlag = '0'
   SET @c_AllocationType = ''
   SET @c_LoadDefaultStrategy = 'N'
   SET @c_ValidStrategy01 = ''
   SET @c_ValidStrategy02 = ''
   SET @c_ValidStrategy03 = ''
   SET @c_CheckSkipPrAllStrg = ''   
   
   SELECT @c_DisableAllocationFlag = ISNULL(clk.Short, ''), 
          @c_AllocationType = clk.Long, 
          @n_RecordFound = 1, 
          @c_ValidStrategy01 = ISNULL(clk.UDF01,''), 
          @c_ValidStrategy02 = ISNULL(clk.UDF02,''),
          @c_ValidStrategy03 = ISNULL(clk.UDF03,''), 
          @c_CheckSkipPrAllStrg = ISNULL(clk.code2,'')    
   FROM CODELKUP AS clk (NOLOCK) 
             WHERE clk.LISTNAME = 'BlockAlloc' 
             AND  (clk.Storerkey = @c_StorerKey) 
             AND  (clk.Notes IS NULL OR clk.Notes = @c_Facility)
             
   IF @n_RecordFound > 0 
   BEGIN
   	IF @c_CheckSkipPrAllStrg = '1' 
   	BEGIN
   		IF NOT EXISTS(SELECT 1 FROM StorerConfig AS sc WITH (NOLOCK)
   		              WHERE sc.StorerKey = @c_StorerKey  
   		                AND sc.ConfigKey LIKE 'SkipPreAllocation' 
   		                AND sc.SValue='1')
   		BEGIN
            SELECT @i_Success = 0, @i_error = '60525', @c_errmsg = 'Skip PreAllocation is Must Turn On for storer: ' + @c_StorerKey
            EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
            RETURN            			
   		END      
   	END      
      IF @c_DisableAllocationFlag = '1'
      BEGIN
         SELECT @i_Success = 0, @i_error = '60525', @c_errmsg = 'Allocation is NOT ALLOW for this Storer'
         EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
         RETURN         
      END
      IF @c_AllocationType = 'BATCH' AND ISNULL(RTRIM(@c_oskey),'') = ''
      BEGIN
         SELECT @i_Success = 0, @i_error = '60526', @c_errmsg = 'Allocation for Batch Only, No Single Order Allocation Allow'
         EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
         RETURN                 
      END

      SELECT @c_SuperOrderFlag = CASE WHEN SuperOrderFlag = 'Y' THEN 'Y'  
                                      ELSE 'N' 
                                 END, 
             @c_LoadDefaultStrategy = ISNULL(DefaultStrategykey, 'N')   
      FROM LOADPLAN WITH (NOLOCK)  
      WHERE LoadKey = @c_oskey
         
      IF @c_AllocationType = 'BATCH'
      BEGIN
         IF @c_SuperOrderFlag <> 'Y'
         BEGIN
            SELECT @i_Success = 0, @i_error = '60527', @c_errmsg = 'Allocation By Batch, Batch Flag in Load NOT selected'
            EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
            RETURN                             
         END          
      END
      IF ISNULL(RTRIM(@c_ValidStrategy01), '') <> '' OR 
         ISNULL(RTRIM(@c_ValidStrategy02), '') <> '' OR
         ISNULL(RTRIM(@c_ValidStrategy03), '') <> '' 
      BEGIN
         IF @c_LoadDefaultStrategy = 'Y' 
         BEGIN
            SET @c_StorerStrategy = ''
            SELECT @c_StorerStrategy = ISNULL(StrategyKey,'') 
            FROM STORER WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            IF ISNULL(RTRIM(@c_StorerStrategy), '') = ''
            BEGIN
               SELECT @c_StorerStrategy = STORERCONFIG.SValue 
               FROM   STORERCONFIG WITH (NOLOCK) 
               WHERE  StorerConfig.StorerKey = @c_Storerkey 
               AND    StorerConfig.Facility = @c_Facility   
               AND    StorerConfig.ConfigKey = 'StorerDefaultAllocStrategy'            
            END

            IF  @c_StorerStrategy NOT IN (@c_ValidStrategy01, @c_ValidStrategy02, @c_ValidStrategy03)
            BEGIN               
               SELECT @i_Success = 0, @i_error = '60528'
               SET @c_errmsg = 'Allocation Strategy Must Either ' + ISNULL(RTRIM(@c_ValidStrategy01), '') + 
                  CASE WHEN ISNULL(RTRIM(@c_ValidStrategy02), '') <> '' THEN '/'  ELSE '' END + 
                  ISNULL(RTRIM(@c_ValidStrategy02), '') +   
                  CASE WHEN ISNULL(RTRIM(@c_ValidStrategy03), '') <> '' THEN '/'  ELSE '' END +
                  ISNULL(RTRIM(@c_ValidStrategy03), '')
               EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
               RETURN               
            END           
            ELSE 
            BEGIN
            	IF @c_CheckSkipPrAllStrg = '1' 
            	BEGIN
            		IF EXISTS(SELECT 1 FROM Strategy AS s WITH (NOLOCK)
            		          WHERE s.StrategyKey = @c_StorerStrategy 
            		          AND   (s.PreAllocateStrategyKey <> '' AND  
            		                 s.PreAllocateStrategyKey IS NOT NULL))
            		BEGIN
                     SELECT @i_Success = 0, @i_error = '60527', @c_errmsg = 'Strategy ' + @c_StorerStrategy + ' is not equal to Skip Pre-allocate Strategy'
                     EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
                     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
                     RETURN               			
            		END
            	END
            END                  
         END
         ELSE 
         BEGIN -- IF @c_LoadDefaultStrategy = 'N'
            IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
            BEGIN
               SELECT TOP 1 
                      @c_SKUStrategy = SKU.StrategyKey  
               FROM   ORDERDETAIL AS OD WITH (NOLOCK) 
               JOIN   SKU WITH (NOLOCK) ON SKU.Sku = OD.Sku AND SKU.StorerKey = OD.StorerKey 
               WHERE  OD.OrderKey = @c_OrderKey            
            END
            ELSE
            BEGIN
               SET @c_SKUStrategy = ''
               SELECT TOP 1 
                      @c_SKUStrategy = SKU.StrategyKey  
               FROM LoadPlanDetail AS lpd WITH (NOLOCK)    
               JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = lpd.OrderKey  
               JOIN SKU WITH (NOLOCK) ON SKU.Sku = OD.Sku AND SKU.StorerKey = OD.StorerKey 
               WHERE lpd.LoadKey = @c_LoadKey   
               
            END

            IF  @c_SKUStrategy NOT IN (@c_ValidStrategy01, @c_ValidStrategy02, @c_ValidStrategy03)
            BEGIN               
               SELECT @i_Success = 0, @i_error = '60529'
               SET @c_errmsg = 'Allocation Strategy Must Either ' + ISNULL(RTRIM(@c_ValidStrategy01), '') + 
                  CASE WHEN ISNULL(RTRIM(@c_ValidStrategy02), '') <> '' THEN '/'  ELSE '' END + 
                  ISNULL(RTRIM(@c_ValidStrategy02), '') +   
                  CASE WHEN ISNULL(RTRIM(@c_ValidStrategy03), '') <> '' THEN '/'  ELSE '' END +
                  ISNULL(RTRIM(@c_ValidStrategy03), '')
               EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
               RETURN               
            END           
            ELSE 
            BEGIN
            	IF @c_CheckSkipPrAllStrg = '1' 
            	BEGIN
            		IF EXISTS(SELECT 1 FROM Strategy AS s WITH (NOLOCK)
            		          WHERE s.StrategyKey = @c_SKUStrategy 
            		          AND   (s.PreAllocateStrategyKey <> '' AND  
            		                 s.PreAllocateStrategyKey IS NOT NULL))
            		BEGIN
                     SELECT @i_Success = 0, @i_error = '60527', @c_errmsg = 'Strategy ' + @c_SKUStrategy + ' is not equal to Skip Pre-allocate Strategy'
                     EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
                     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR     
                     RETURN               			
            		END
            	END
            END                            
         END -- IF @c_LoadDefaultStrategy = 'N'
      END -- IF ISNULL(RTRIM(@c_ValidStrategy0X), '') <> ''
   END
   --  SHONG01 SOS#349953 (End)                    
           
   /* IDSV5 - Leo */  
   DECLARE @c_authority NVARCHAR(1)  
   SELECT @i_Success = 0  

   /* REMOVE THIS IF 'CheckManualAlloc' DEPLOYED TO ALL COUNTRY */
   IF EXISTS(SELECT 1 FROM NSQLCONFIG WITH (NOLOCK) WHERE Configkey = 'ALLOW ALLOCATION') 
   BEGIN
      UPDATE NSQLCONFIG WITH (ROWLOCK)
      SET ConfigKey = 'CheckManualAlloc', NSQLDescrip = 'If turned on, will block manual allocation if exists backend schedule allocation'
      WHERE ConfigKey = 'ALLOW ALLOCATION'
   END

   IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Configkey = 'ALLOW ALLOCATION')     
   BEGIN
      IF EXISTS(SELECT 1 FROM NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'CheckManualAlloc' AND NSQLValue = '1')
      BEGIN
         DELETE FROM StorerConfig
         WHERE ConfigKey = 'ALLOW ALLOCATION'
      END
      ELSE 
      BEGIN
         DELETE FROM StorerConfig
         WHERE Configkey = 'ALLOW ALLOCATION'
         AND SValue <> '1'    

         UPDATE STORERCONFIG WITH (ROWLOCK)
         SET Configkey = 'CheckManualAlloc', ConfigDesc = 'If turned on, will block manual allocation if exists backend schedule allocation'
         WHERE Configkey = 'ALLOW ALLOCATION'     
      END
   END
   /* REMOVE THIS IF 'CheckManualAlloc' DEPLOYED TO ALL COUNTRY */
   
   --NJOW08 S
   SET @c_PreRunStrategykey = ''  
                                 
   EXEC nspGetRight    
        @c_Facility  = @c_Facility,   
        @c_StorerKey = @c_StorerKey,    
        @c_sku       = NULL,    
        @c_ConfigKey = 'PreRunStrategy',     
        @b_Success   = @I_Success                  OUTPUT,    
        @c_authority = @c_PreRunStrategykey        OUTPUT,     
        @n_err       = @i_error                    OUTPUT,     
        @c_errmsg    = @c_errmsg                   OUTPUT    
   --NJOW08 E     

   Execute nspGetRight 
            @c_Facility,  --NJOW05  
            @c_StorerKey, -- Chee01 
            null,         -- Sku  
            --'ALLOW ALLOCATION'     -- Chee01
            'CheckManualAlloc',      -- ConfigKey  
            @i_Success    output,  
            @c_authority  output,  
            @i_error      output,  
            @c_errmsg     output  

   IF @i_Success <> 1  
   BEGIN  
      SELECT @c_errmsg = 'nsp_OrderProcessing_Wrapper :' + dbo.fnc_RTrim(@c_errmsg)  
   END  
   ELSE  
   BEGIN  
      --NJOW04 Start                 
      SELECT TOP 1 @c_AllocateValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
      AND SC.Configkey = 'PreAllocateExtendedValidation'
      ORDER BY SC.Facility DESC
      
      IF ISNULL(@c_AllocateValidationRules,'') <> ''
      BEGIN
         EXEC isp_Allocate_ExtendedValidation @c_Orderkey = @c_Orderkey,
                                              @c_Loadkey = @c_oskey,
                                              @c_Wavekey = '',
                                              @c_Mode = 'PRE',
                                              @c_AllocateValidationRules=@c_AllocateValidationRules,
                                              @b_Success=@i_Success OUTPUT, 
                                              @c_ErrMsg=@c_ErrMsg OUTPUT         
                                              
         IF @i_Success <> 1  
         BEGIN  
            EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
         END  
      END
      ELSE   
      BEGIN
         SELECT TOP 1 @c_AllocateValidationRules = SC.sValue    
         FROM STORERCONFIG SC (NOLOCK) 
         WHERE SC.StorerKey = @c_StorerKey 
         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
         AND SC.Configkey = 'PreAllocateExtendedValidation'    
         ORDER BY SC.Facility DESC
         
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_AllocateValidationRules) AND type = 'P')          
         BEGIN          
            SET @c_SQL = 'EXEC ' + @c_AllocateValidationRules + ' @c_Orderkey, @c_Loadkey, @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
            EXEC sp_executesql @c_SQL,          
                 N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
                 @c_Orderkey,          
                 @c_oskey,
                 '',
                 @i_Success OUTPUT,          
                 @i_error OUTPUT,          
                 @c_ErrMsg OUTPUT
                     
            IF @i_Success <> 1     
            BEGIN    
               EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RETURN
            END         
         END  
      END            
      --NJOW04 End

      --NJOW06 Start      
      EXEC isp_PrePostAllocate_Process @c_Orderkey = @c_Orderkey,
                                       @c_Loadkey = @c_oskey,
                                       @c_Wavekey = '',
                                       @c_Mode = 'PRE',
                                       @c_extendparms = @c_extendparms,
                                       @c_StrategykeyParm = @c_StrategykeyParm, --NJOW07
                                       @b_Success = @i_Success OUTPUT,          
                                       @n_Err = @i_error OUTPUT,          
                                       @c_Errmsg = @c_ErrMsg OUTPUT
                                           
      IF @i_Success <> 1  
      BEGIN  
         EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END  
      --NJOW06 End                     
            	
      IF @c_authority = '1'  
      BEGIN  
         IF ISNULL(RTrim(@c_oskey), '') = ''  -- SHONG01
         BEGIN  
            -- (YokeBeen01) - Start 
            IF EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK)
                        JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.OrderKey 
                                                  AND TRANSMITLOG.Key2 = ORDERS.Type 
                                                  AND TRANSMITLOG.Key3 = ORDERS.StorerKey) 
            --            JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.ExternOrderKey) 
                        WHERE TRANSMITLOG.TableName = 'ORDALLOC'  
                        AND TRANSMITLOG.TransmitFlag IN ('0','9')  
                        AND ORDERS.OrderKey = @c_OrderKey )  
            -- (YokeBeen01) - End 
            BEGIN  
               SELECT @b_AllowAllocate = 0  
            END  
            --  END  
  
            IF @b_AllowAllocate = 1 --Added By Vicky 18 July 2002 Patches from IDSHK  
            BEGIN --5  
               IF EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK)
                           JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.OrderKey) 
                           WHERE TRANSMITLOG.TableName = 'OWORDALLOC'  
                           AND TRANSMITLOG.TransmitFlag IN ('0','9')  
                           AND ORDERS.OrderKey = @c_OrderKey )  
               BEGIN  
                  SELECT @b_AllowAllocate = 0  
               END  
            END --End Add  
         END  -- IF ISNULL(RTrim(@c_oskey), '') = ''  
         ELSE  
         BEGIN  
            -- (YokeBeen01) - Start 
            IF EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK)
                        JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.OrderKey 
                                                  AND TRANSMITLOG.Key2 = ORDERS.Type 
                                                  AND TRANSMITLOG.Key3 = ORDERS.StorerKey) 
            --            JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.ExternOrderKey) 
                        WHERE TRANSMITLOG.TableName = 'ORDALLOC'  
                        AND TRANSMITLOG.TransmitFlag IN ('0','9')  
                        AND ORDERS.Userdefine08 <> 'Y'  
                        AND ORDERS.LoadKey = @c_oskey)  
            -- (YokeBeen01) - End 
            BEGIN  
               SELECT @b_AllowAllocate = 0  
            END  
            -- END  
  
            IF @b_AllowAllocate = 1 --Added By Vicky 18 July 2002 Patches from IDSHK  
            BEGIN --7  
               IF EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK)
                           JOIN ORDERS WITH (NOLOCK) ON (TRANSMITLOG.Key1 = ORDERS.OrderKey) 
                           WHERE TRANSMITLOG.TableName = 'OWORDALLOC'  
                           AND TRANSMITLOG.TransmitFlag IN ('0','9')  
                           AND ORDERS.Userdefine08 <> 'Y'  
                           AND ORDERS.LoadKey = @c_oskey)  
               BEGIN  
                  SELECT @b_AllowAllocate = 0  
               END  
            END  --End Add  
         END  
  
         IF @b_AllowAllocate = 1  
         BEGIN  
            --NJOW Start
            SET @c_PreAllocationSP = ''
                                        
            EXEC nspGetRight  
                 @c_Facility  = @c_Facility,  --NJOW05
                 @c_StorerKey = @c_StorerKey,  
                 @c_sku       = NULL,  
                 @c_ConfigKey = 'PreAllocationSP',   
                 @b_Success   = @i_Success                  OUTPUT,  
                 @c_authority = @c_PreAllocationSP          OUTPUT,   
                 @n_err       = @i_error                    OUTPUT,   
                 @c_errmsg    = @c_errmsg                   OUTPUT  
            
            IF (EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PreAllocationSP AND TYPE = 'P')   
                OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PreAllocationSP)) --NJOW09           
               AND (ISNULL(@c_PreRunStrategykey,'') <> @c_StrategykeyParm OR ISNULL(@c_PreRunStrategykey,'')='') --NJOW08
            BEGIN  
               SET @i_Success = 0  
               
               EXECUTE dbo.ispPreAllocationWrapper 
                       @c_OrderKey = @c_OrderKey
                     , @c_LoadKey  = @c_oskey  
                     , @c_PreAllocationSP = @c_PreAllocationSP  
                     , @b_Success = @i_Success     OUTPUT  
                     , @n_Err     = @i_error       OUTPUT   
                     , @c_ErrMsg  = @c_errmsg      OUTPUT  
                     , @b_debug   = 0 
            
               IF @i_error <> 0  
               BEGIN  
                  SELECT @i_Success = 0, @i_error = '60524', @c_errmsg = 'Execute ' + @c_PreAllocationSP + ' Failed'
                  EXECUTE nsp_logerror @i_error, @c_errmsg, @c_PreAllocationSP
                  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                  RETURN
               END  
            END      
            --NJOW End     
            
            -- Added By Shong  
            -- Date: 22 Jan 2002  
            -- Disable cartonization, Not applicable in IDS  
            -- Also improve performance.  
            -- But this SP must work together with IDS's nspOrderprocessing 
            SET @c_Trace_ModuleName = 'OrderProcessing' 
            SET @d_Trace_Step1 = GETDATE()
            EXECUTE nsporderprocessing 
                     @c_OrderKey = @c_OrderKey,  
                     @c_oskey = @c_oskey,  
                     @c_docarton = 'N', -- @c_docarton,  
                     @c_doroute = @c_doroute,  
                     @c_tblprefix = @c_tblprefix,
                     @b_Success = @i_Success OUTPUT,  
                     @n_err = @i_error OUTPUT,  
                     @c_errmsg = @c_errmsg OUTPUT,  
                     @c_extendparms = @c_extendparms,          --(Wan01)  
                     @c_StrategykeyParm = @c_StrategykeyParm  --NJOW07
                                 
            IF @b_debug = 1 AND @i_error <> 0 
               SELECT @i_Success, @i_error, @c_errmsg  
               
            SET @c_Trace_Step1 = CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114)
            
            -- Added by SHONG 
            -- Date: 07-Jun-2010 
            -- Capture Allocation Shortage after allocation
            IF LEN(@c_OrderKey) > 0 
               EXEC isp_InsertAllocShortageLog @cOrderKey = @c_OrderKey
            ELSE IF LEN(@c_oskey) > 0 
               EXEC isp_InsertAllocShortageLog @cLoadKey = @c_oskey
               
            -- Added By Shong 
            -- Date: 13-11-2013
            -- Execute Post Action after Allocation
            SET @c_PostAllocationSP = ''
                                        
            EXEC nspGetRight  
                 @c_Facility  = @c_facility,  --NJOW05
                 @c_StorerKey = @c_StorerKey,  
                 @c_sku    = NULL,  
                 @c_ConfigKey = 'PostAllocationSP',   
                 @b_Success   = @i_Success                  OUTPUT,  
                 @c_authority = @c_PostAllocationSP         OUTPUT,   
                 @n_err       = @i_error                    OUTPUT,   
                 @c_errmsg    = @c_errmsg                   OUTPUT  
            
            IF (EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PostAllocationSP AND TYPE = 'P')            
                OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PostAllocationSP))  --NJOW02
               AND (ISNULL(@c_PreRunStrategykey,'') <> @c_StrategykeyParm OR ISNULL(@c_PreRunStrategykey,'')='') --NJOW08
            BEGIN  
               SET @i_Success = 0  
               SET @c_Trace_Col4 = @c_PostAllocationSP 
               
               EXECUTE dbo.ispPostAllocationWrapper 
                       @c_OrderKey = @c_OrderKey
                     , @c_LoadKey  = @c_oskey  
                     , @c_PostAllocationSP = @c_PostAllocationSP  
                     , @b_Success = @i_Success     OUTPUT  
                     , @n_Err     = @i_error       OUTPUT   
                     , @c_ErrMsg  = @c_errmsg      OUTPUT  
                     , @b_debug   = @b_debug 
            
               IF @i_error <> 0  
               BEGIN  
                  SELECT @i_Success = 0, @i_error = '60544', @c_errmsg = 'Execute ' + @c_PostAllocationSP + ' Failed'
                  EXECUTE nsp_logerror @i_error, @c_errmsg, @c_PostAllocationSP
                  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                  RETURN
               END  
            END                    
         END  
         ELSE  
         BEGIN  
            SELECT @i_Success = 0, @i_error = '60543', @c_errmsg = 'Pick Slip Printed/Interface Done. No Allocation Allowed'  
            EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'  
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
            RETURN  
            -- SELECT @i_Success, @i_error, @c_errmsg  
         END  
      END -- IF @c_authority = '1' 
      ELSE  
      BEGIN  
--         --NJOW move up from bottom
--         IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
--         BEGIN
--            SELECT @c_StorerKey = StorerKey 
--            FROM   ORDERS o WITH (NOLOCK)
--            WHERE o.OrderKey = @c_OrderKey            
--         END 
--         ELSE
--         BEGIN
--            SELECT TOP 1 
--                   @c_StorerKey = o.StorerKey 
--            FROM   ORDERS o WITH (NOLOCK) 
--            JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = o.OrderKey
--            WHERE lpd.LoadKey = @c_oskey            
--         END         

         --NJOW03 Start
            EXECUTE dbo.isp_OTMPlanModeAllocationCheck 
                    @c_OrderKey = @c_OrderKey
                  , @c_LoadKey  = @c_oskey  
                  , @c_Wavekey = ''
                  , @b_Success = @i_Success     OUTPUT  
                  , @n_Err     = @i_error       OUTPUT   
                  , @c_ErrMsg  = @c_errmsg      OUTPUT  

            IF @i_error <> 0  
            BEGIN  
			   PRINT 'FAILED isp_OTMPlanModeAllocationCheck' + '---' + @c_errmsg  
               EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RETURN
            END  
         --NJOW03 End
                 
         --NJOW Start
         SET @c_PreAllocationSP = ''
                                     
         EXEC nspGetRight  
              @c_Facility  = @c_facility,   --NJOW05
              @c_StorerKey = @c_StorerKey,  
              @c_sku       = NULL,  
              @c_ConfigKey = 'PreAllocationSP',   
              @b_Success   = @i_Success                  OUTPUT,  
              @c_authority = @c_PreAllocationSP          OUTPUT,   
              @n_err       = @i_error                    OUTPUT,   
              @c_errmsg    = @c_errmsg                   OUTPUT  
   
         IF (EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PreAllocationSP AND TYPE = 'P')   
             OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PreAllocationSP)) --NJOW09                    
            AND (ISNULL(@c_PreRunStrategykey,'') <> @c_StrategykeyParm OR ISNULL(@c_PreRunStrategykey,'')='') --NJOW08
         BEGIN  
            SET @i_Success = 0  
            
            EXECUTE dbo.ispPreAllocationWrapper 
                    @c_OrderKey = @c_OrderKey
                  , @c_LoadKey  = @c_oskey  
                  , @c_PreAllocationSP = @c_PreAllocationSP  
                  , @b_Success = @i_Success     OUTPUT  
                  , @n_Err     = @i_error       OUTPUT   
                  , @c_ErrMsg  = @c_errmsg      OUTPUT  
                  , @b_debug   = 0 
		
            IF @i_error <> 0  
            BEGIN  
			   PRINT 'FAILEd TO EXECUTE ispPreAllocationWrapper' + '----' + @c_errmsg
               SELECT @i_Success = 0, @i_error = '60524', @c_errmsg = 'Execute ' + @c_PreAllocationSP + ' Failed'
               EXECUTE nsp_logerror @i_error, @c_errmsg, @c_PreAllocationSP
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RETURN
            END  
         END      
         --NJOW End     

         -- Added By SHONG on 26-Jul-2004 (SOS# 25496)  
         -- Allocation for China (Group by CaseCnt and Get from Bulk)  
  
         IF ISNULL(RTrim(@c_oskey),'') <> '' -- SHONG01   
         BEGIN  
            SELECT @c_SuperOrderFlag = CASE WHEN SuperOrderFlag = 'Y' THEN 'Y'  
                                            ELSE 'N' END  
            FROM LOADPLAN WITH (NOLOCK)  
            WHERE LoadKey = @c_oskey  
               -- TLTING01
            IF @c_SuperOrderFlag = 'Y' AND   
                 EXISTS (SELECT 1 FROM StorerConfig SC WITH (NOLOCK)   
         				         JOIN  ( SELECT TOP 1    O.Storerkey FROM ORDERS O WITH (NOLOCK)   
         				         JOIN   LoadPlanDetail LP WITH (NOLOCK) ON (LP.OrderKey = O.OrderKey)
         				         WHERE  LP.LoadKey = @c_oskey   ) AS A ON A.StorerKey = SC.StorerKey
                         WHERE SC.ConfigKey = 'CartonConsoAllocation' AND SC.sValue = '1'   
                         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '') --NJOW05
                         )          
            BEGIN  
               SELECT @n_ConsoCaseAlloc = 1  
                              
               -- CN NIKE Bridge
               
               -- TLTING01
               SELECT TOP 1 @c_Facility = FC.Facility
               FROM FACILITY FC WITH (NOLOCK) 
               JOIN ( SELECT OH.Facility FROM ORDERS OH WITH (NOLOCK) 
					     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey) 
					     WHERE LPD.LoadKey = @c_oskey ) AS A ON (FC.Facility = A.Facility) 

               -- Check at facility level
               SELECT @i_Success = 0
               EXECUTE nspGetRight @c_Facility, -- Facility
                  NULL,                         -- Storerkey
                  NULL,                         -- Sku
                  'LoadPlanDynamicAllocByUCC',  -- Configkey
                  @i_Success                   OUTPUT,
                  @c_LoadPlanDynamicAllocByUCC OUTPUT, 
                  @i_error                     OUTPUT,
                  @c_errmsg                    OUTPUT
                  
               IF @i_Success <> 1
               BEGIN
                  SELECT @i_Success = 0, @i_error = '60544', @c_errmsg = 'Get LoadPlanDynamicAllocByUCC error. No Allocation Allowed'
                  EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_OrderProcessing_Wrapper'
                  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                  RETURN
               END               
            END  
            ELSE  
            BEGIN  
               SELECT @n_ConsoCaseAlloc = 0   
                     -- TLTING01
               IF @c_SuperOrderFlag = 'Y' AND   
                   EXISTS (SELECT 1 FROM StorerConfig SC WITH (NOLOCK)   
   					               JOIN ( SELECT TOP 1 O.StorerKey
                           FROM ORDERS O WITH (NOLOCK)
                           JOIN LoadPlanDetail LP WITH (NOLOCK) ON (LP.OrderKey = O.OrderKey)   
                           WHERE LP.LoadKey = @c_oskey ) AS A ON (SC.StorerKey = A.StorerKey) 
      						         WHERE SC.ConfigKey = 'PrePackConsoAllocation' AND SC.sValue = '1'   
                           AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '') )--NJOW05 )  
 
               BEGIN  
                  SELECT @n_PrePackAlloc = 1  
               END  
               ELSE  
               BEGIN 
                  SELECT @n_PrePackAlloc = 0   
               END 

               SET @n_LoadConsoAllocation = 0 
               
               IF @c_SuperOrderFlag = 'Y' AND
                  EXISTS ( SELECT 1
                           FROM   StorerConfig SC WITH (NOLOCK) 
         					         JOIN ( SELECT TOP 1 O.StorerKey
                                  FROM ORDERS O WITH (NOLOCK)
                                  JOIN LoadPlanDetail LP WITH (NOLOCK) ON (LP.OrderKey = O.OrderKey)   
                                  WHERE LP.LoadKey = @c_oskey ) AS A ON (SC.StorerKey = A.StorerKey) 
                           WHERE  SC.ConfigKey = 'LoadConsoAllocation' AND  SC.sValue = '1' 
                           AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '') --NJOW05
                             ) 
               BEGIN
                  SET @n_LoadConsoAllocation = 1
               END
               ELSE 
               BEGIN 
                  SET @n_LoadConsoAllocation = 0      
               END 
            END   
         END  

         IF @n_ConsoCaseAlloc = 1  
         BEGIN  
            IF @c_LoadPlanDynamicAllocByUCC = '1'
            BEGIN
               SET @c_Trace_ModuleName = 'ProcessingByCase_UCC'
               SET @d_Trace_Step1 = GETDATE()
               
               EXECUTE nspOrderProcessingByCase_UCC '',
                        @c_oskey,
                        'N', -- @c_docarton,
                        @c_doroute,
                        @c_tblprefix,
                        @i_Success OUTPUT,
                        @i_error OUTPUT,
                        @c_errmsg OUTPUT
                         
            END
            ELSE
            BEGIN
               SET @c_Trace_ModuleName = 'ProcessingByCase'
               SET @d_Trace_Step1 = GETDATE()
               
               EXECUTE nspOrderProcessingByCase '',
                        @c_oskey,
                        'N', -- @c_docarton,
                        @c_doroute,
                        @c_tblprefix,
                        @i_Success OUTPUT,
                        @i_error OUTPUT,
                        @c_errmsg OUTPUT 
            END   
  
            IF @b_debug = 1 AND @i_error <> 0 
            BEGIN
            	SELECT @i_Success, @i_error, @c_errmsg
            END
                 
               
            SET @c_Trace_Step1 = CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114) 
         END  
         ELSE IF @n_PrePackAlloc = 1  
         BEGIN  
            SET @c_Trace_ModuleName = 'ProcessingByPrePack'
            SET @d_Trace_Step1 = GETDATE()
                        
            EXECUTE ispOrderProcessingByPrePack '',  
                     @c_oskey,  
                     'N', -- @c_docarton,  
                     @c_doroute,  
                     @c_tblprefix,  
                     @i_Success OUTPUT,  
                     @i_error OUTPUT,  
                     @c_errmsg OUTPUT  
  
            IF @b_debug = 1 AND @i_error <> 0 
               SELECT @i_Success, @i_error, @c_errmsg
   
            SET @c_Trace_Step1 = CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114)   
         END  
         ELSE IF @n_LoadConsoAllocation = 1
         BEGIN
            SET @c_Trace_ModuleName = 'LoadProcessing'
            SET @d_Trace_Step1 = GETDATE() 
                        
            EXECUTE dbo.nspLoadProcessing 
               @c_LoadKey = @c_oskey,
               @b_Success = @i_Success OUTPUT, @n_Err = @i_error OUTPUT,
               @c_ErrMsg = @c_errmsg OUTPUT, @b_Debug = @b_debug, --0
               @c_StrategykeyParm = @c_StrategykeyParm --NJOW07

            IF @b_debug = 1 AND @i_error <> 0 
               SELECT @i_Success, @i_error, @c_errmsg               
               
            SET @c_Trace_Step1 = CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114) 
         END         
         ELSE  
         BEGIN           
            SET @c_Trace_ModuleName = 'OrderProcessing'
            SET @d_Trace_Step1 = GETDATE()

            EXECUTE nsporderprocessing 
                     @c_OrderKey = @c_OrderKey,  
                     @c_oskey = @c_oskey,  
                     @c_docarton = 'N', -- @c_docarton,  
                     @c_doroute = @c_doroute,  
                     @c_tblprefix = @c_tblprefix,
                     @b_Success = @i_Success OUTPUT,  
                     @n_err = @i_error OUTPUT,  
                     @c_errmsg = @c_errmsg OUTPUT,  
                     @c_extendparms = @c_extendparms,          --(Wan01)  
                     @c_StrategykeyParm = @c_StrategykeyParm  --NJOW07
              
            IF @b_debug = 1 AND @i_error <> 0 
               SELECT @i_Success, @i_error, @c_errmsg  
               
            SET @c_Trace_Step1 = CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114) 
         END   
         -- Added by SHONG 
         -- Date: 07-Jun-2010 
         -- Capture Allocation Shortage after allocation
         IF LEN(@c_OrderKey) > 0 
            EXEC isp_InsertAllocShortageLog @cOrderKey = @c_OrderKey
         ELSE IF LEN(@c_oskey) > 0 
            EXEC isp_InsertAllocShortageLog @cLoadKey = @c_oskey                

         -- Added By Shong 
         -- Date: 13-11-2013
         -- Execute Post Action after Allocation
         
         SET @c_PostAllocationSP = ''
                                     
         EXEC nspGetRight  
              @c_Facility  = @c_Facility,  --NJOW05
              @c_StorerKey = @c_StorerKey,  
              @c_sku       = NULL,  
              @c_ConfigKey = 'PostAllocationSP',   
              @b_Success   = @i_Success                  OUTPUT,  
              @c_authority = @c_PostAllocationSP         OUTPUT,   
              @n_err       = @i_error                    OUTPUT,   
              @c_errmsg    = @c_errmsg                   OUTPUT  
        
         IF (EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PostAllocationSP AND TYPE = 'P')            
            OR EXISTS(SELECT 1 FROM AllocateStrategy (NOLOCK) WHERE AllocateStrategyKey = @c_PostAllocationSP))  --NJOW02
            AND (ISNULL(@c_PreRunStrategykey,'') <> @c_StrategykeyParm OR ISNULL(@c_PreRunStrategykey,'')='') --NJOW08
         BEGIN  
            SET @i_Success = 0  
            SET @c_Trace_Col4 = @c_PostAllocationSP 
            
            IF @b_debug = 1
            BEGIN
            	PRINT '-- EXEC ispPostAllocationWrapper: ' + @c_PostAllocationSP 
            END
            
            EXECUTE dbo.ispPostAllocationWrapper 
                    @c_OrderKey = @c_OrderKey
                  , @c_LoadKey  = @c_oskey  
                  , @c_PostAllocationSP = @c_PostAllocationSP  
                  , @b_Success = @i_Success     OUTPUT  
                  , @n_Err     = @i_error       OUTPUT   
                  , @c_ErrMsg  = @c_errmsg      OUTPUT  
                  , @b_debug   = @b_debug  

            IF @i_error <> 0  
            BEGIN  
               SELECT @i_Success = 0, @i_error = '60544', @c_errmsg = 'Execute ' + @c_PostAllocationSP + ' Failed'
               EXECUTE nsp_logerror @i_error, @c_errmsg, @c_PostAllocationSP
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RETURN
            END  
         END           
      End  

      --NJOW06 Start      
      EXEC isp_PrePostAllocate_Process @c_Orderkey = @c_Orderkey,
                                       @c_Loadkey = @c_oskey,
                                       @c_Wavekey = '',
                                       @c_Mode = 'POST',
                                       @c_extendparms = @c_extendparms,
                                       @c_StrategykeyParm = @c_StrategykeyParm, --NJOW07                                       
                                       @b_Success = @i_Success OUTPUT,          
                                       @n_Err = @i_error OUTPUT,          
                                       @c_Errmsg = @c_ErrMsg OUTPUT
                                           
      IF @i_Success <> 1  
      BEGIN  
         EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END  
      --NJOW06 End                     

      --NJOW04 Start                 
      SELECT TOP 1 @c_AllocateValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
      AND SC.Configkey = 'PostAllocateExtendedValidation'
      ORDER BY SC.Facility DESC
      
      IF ISNULL(@c_AllocateValidationRules,'') <> ''
      BEGIN
         EXEC isp_Allocate_ExtendedValidation @c_Orderkey = @c_Orderkey,
                                              @c_Loadkey = @c_oskey,
                                              @c_Wavekey = '',
                                              @c_Mode = 'POST',
                                              @c_AllocateValidationRules=@c_AllocateValidationRules,
                                              @b_Success=@i_Success OUTPUT, 
                                              @c_ErrMsg=@c_ErrMsg OUTPUT         
                                              
         IF @i_Success <> 1  
         BEGIN  
            EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
         END  
      END
      ELSE   
      BEGIN
         SELECT TOP 1 @c_AllocateValidationRules = SC.sValue    
         FROM STORERCONFIG SC (NOLOCK) 
         WHERE SC.StorerKey = @c_StorerKey 
         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '')
         AND SC.Configkey = 'PostAllocateExtendedValidation'    
         ORDER BY SC.Facility DESC
         
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_AllocateValidationRules) AND type = 'P')          
         BEGIN   

            IF @b_debug = 1
            BEGIN
            	PRINT '-- EXEC PostAllocateExtendedValidation Rules: ' + @c_AllocateValidationRules 
            END
                     	       
            SET @c_SQL = 'EXEC ' + @c_AllocateValidationRules + ' @c_Orderkey, @c_Loadkey, @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
            EXEC sp_executesql @c_SQL,          
                 N'@c_OrderKey NVARCHAR(10), @c_LoadKey NVARCHAR(10), @c_WaveKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
                 @c_Orderkey,          
                 @c_oskey,
                 '',
                 @i_Success OUTPUT,          
                 @i_error OUTPUT,          
                 @c_ErrMsg OUTPUT
                     
            IF @i_Success <> 1     
            BEGIN    
               EXECUTE nsp_logerror @i_error, @c_errmsg, 'nsp_orderprocessing_wrapper'
               RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
               RETURN
            END         
         END  
      END            
      --NJOW04 End                  
   End -- IF @i_Success <> 1 (ALLOW ALLOCATION) 

EXIT_SP:
   
   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'StdAllocation',
      @c_TraceName = 'nsp_OrderProcessing_Wrapper',
      @c_starttime = @d_Trace_StartTime,
      @c_endtime = @d_Trace_EndTime,
      @c_step1 = @c_Trace_Step1,
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_OrderKey,
      @c_col2 = @c_oskey,
      @c_col3 = @c_Trace_ModuleName,
      @c_col4 = @c_Trace_Col4,
      @c_col5 = @c_UserName,
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = ''      
END  


GO