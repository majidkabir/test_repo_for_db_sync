SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispAsgnTNo2                                         */    
/* Creation Date: 13-Nov-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Rev  Purposes                                  */    
/* 13-Apr-2017  TLTING   2.1  V2 Initial Version                        */
/* 21-JUN-2017  Wan01    2.1  WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/* 21-JUN-2017  Wan02    2.2  WMS-2306 - CN-Nike SDC WMS ECOM Packing CR*/
/* 28-Sep-2017  TLTING   2.1  Merge Dyson Version                       */
/* 20-Oct-2017  TLTING01 2.3  exclude online courier orders             */
/* 23-Oct-2017  TLTING   2.4  Update TrackingNo                         */
/* 29-Nov-2018	NJOW01   2.5  WMS-7148 CN Step new mapping              */
/* 14-Jan-2019  TLTING02 2.6  Performance tune                          */
/* 18-Mar-2020  TLTING03 2.7  fixes                                     */
/* 10-Jun-2020  TLTING04 2.8  WMS13667 - PRTFLAG                        */
/* 14-Jul-2021  NJOW02   2.9  WMS-17493 Add wavekey parameter           */
/* 18-Aug-2021  NJOW03   3.0  WMS-14231 add config to change carrier    */
/*                            field mapping                             */
/* 09-May-2022  NJOW04   3.1  WMS-19622 filter orderinfo02 by config    */ 
/* 09-May-2022  NJOW04   3.1  DEVOPS combine script                     */ 
/* 29-May-2023  NJOW05   3.1  WMS-22689 allow disable SKIPTRKNO codelkup*/
/*                            config by childflag=1 (second ctn)        */
/************************************************************************/ 

CREATE   PROC [dbo].[ispAsgnTNo2]      
     @c_OrderKey    NVARCHAR(10)    
   , @c_LoadKey     NVARCHAR(10)  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0      
   , @b_ChildFlag   INT = 0                     --(Wan01)
   , @c_TrackingNo  NVARCHAR(20) = '' OUTPUT    --(Wan01)    
   , @c_Wavekey     NVARCHAR(10) = ''  --NJOW02   
AS      
BEGIN      
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
      
   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT, -- Holds the current transaction count  
            @n_Retry       INT,        
            @c_Udef04      NVARCHAR(80),   
           --@c_TrackingNo  NVARCHAR(20),    --(Wan01) 
            @n_RowRef      INT,   
            @c_StorerKey   NVARCHAR(15), -- (shong02)  
            @c_Udef02      NVARCHAR(20),  
            @c_Udef03      NVARCHAR(20), -- (SOS#332990)  
            @c_OrderType   NVARCHAR(10)  -- (SOS#345781)  

   --NJOW04
   DECLARE  @c_option1     NVARCHAR(50),
            @c_option2     NVARCHAR(50),
            @c_option3     NVARCHAR(50),
            @c_option4     NVARCHAR(50),
            @c_option5     NVARCHAR(4000),
            @c_authority   NVARCHAR(30),
            @c_Orderinfo02Filter NVARCHAR(10)='',    
            @c_ECOM_Platform     NVARCHAR(30)
  
   DECLARE @c_KeyName      NVARCHAR(30)  
          ,@c_Facility     NVARCHAR(5)  
          ,@c_Shipperkey   NVARCHAR(15)  
          ,@c_CarrierName  NVARCHAR(30)  
          ,@c_labelNo      NVARCHAR(20)  --(Wan02)
  
   DECLARE @c_CLK_UDF02           NVARCHAR(30)  
         , @c_UpdateEComDstntCode CHAR(1)  
   DECLARE @c_CarrierRef1  NVARCHAR(40)  
   DECLARE @n_SuccessFlag       Int  

   DECLARE @c_PRTFLAG      NVARCHAR(60)    --tlting04
   
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0    
   SELECT @c_ErrMsg=''    
      
   IF @n_Continue=1 OR @n_Continue=2      
   BEGIN      
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_WaveKey),'') = ''   --NJOW02
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63500      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispAsgnTNo2)'  
         GOTO EXIT_SP      
      END      
   END -- @n_Continue =1 or @n_Continue = 2      
    
   IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
   BEGIN  
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey   
      FROM ORDERS WITH (NOLOCK)  
      WHERE OrderKey = @c_OrderKey  
      AND   ShipperKey IS NOT NULL 
      AND   ShipperKey <> ''  
      AND   sostatus <> 'PENDGET'      -- tlting01
   END  
   ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''   
   BEGIN  
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT lpd.OrderKey   
      FROM LoadplanDetail AS lpd WITH (NOLOCK) 
      JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey       
      WHERE lpd.LoadKey = @c_LoadKey        
      AND   o.ShipperKey IS NOT NULL 
      AND   o.ShipperKey <> ''
      AND   o.sostatus <> 'PENDGET'    -- tlting01
   END  
   ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  --NJOW02
   BEGIN
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT wd.OrderKey   
      FROM WaveDetail AS wd WITH (NOLOCK) 
      JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = wd.OrderKey       
      WHERE wd.WaveKey = @c_WaveKey        
      AND   o.ShipperKey IS NOT NULL 
      AND   o.ShipperKey <> ''
      AND   o.sostatus <> 'PENDGET'    -- tlting01
   END
     
   OPEN CUR_ORDERKEY      
  
   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
   
 --NJOW04 S
   SELECT @c_Storerkey = Storerkey,
          @c_Facility = Facility
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   Execute nspGetRight                                
      @c_Facility  = @c_facility,                     
      @c_StorerKey = @c_StorerKey,                    
      @c_sku       = '',                          
      @c_ConfigKey = 'PostAllocationSP', -- Configkey         
      @b_Success   = @b_success   OUTPUT,             
      @c_authority = @c_authority OUTPUT,             
      @n_err       = @n_err       OUTPUT,             
      @c_errmsg    = @c_errmsg    OUTPUT,             
      @c_Option1   = @c_option1   OUTPUT,               
      @c_Option2   = @c_option2   OUTPUT,               
      @c_Option3   = @c_option3   OUTPUT,               
      @c_Option4   = @c_option4   OUTPUT,               
      @c_Option5   = @c_option5   OUTPUT            
            
   SET @c_Orderinfo02Filter = dbo.fnc_GetParamValueFromString('@c_Orderinfo02Filter', @c_option5, @c_Orderinfo02Filter) 
   --NJOW04 E   
    
   WHILE @@FETCH_STATUS <> -1          
   BEGIN         
      --IF @b_debug=1      
      --BEGIN      
      --   PRINT @c_OrderKey         
      --END      
  
      SET @c_Udef04 = ''  
      SET @c_StorerKey = ''  
      SET @c_ShipperKey = ''  
      SET @c_Facility = ''  
      SET @c_Udef02 = ''  
      SET @c_Udef03 = ''    -- (SOS#332990)
      SET @c_OrderType = '' -- (SOS#345781)    
      SET @c_ECOM_Platform = ''
        
      SELECT @c_Udef04     = ISNULL(o.UserDefine04,''),   
             @c_StorerKey  = o.StorerKey,   
             @c_ShipperKey = CASE WHEN CFG.Authority = '1' AND CFG.Option1 = 'M_FAX2' THEN ISNULL(o.M_Fax2,'') ELSE ISNULL(o.ShipperKey,'') END,  --NJOW03                
             @c_Facility   = o.Facility,  
             @c_Udef02     = ISNULL(o.UserDefine02,''),  
             @c_Udef03     = ISNULL(o.UserDefine03,''), -- (SOS#332990)  
             @c_OrderType  = ISNULL(o.[Type], ''),
             @c_ECOM_Platform = ISNULL(o.ECOM_Platform, '') --NJOW04
      FROM ORDERS o WITH (NOLOCK)                                             
      OUTER APPLY(SELECT Authority, Option1 from dbo.fnc_getright2(o.facility, O.storerkey,'','AsgnTnoGetCarrierFrom')) CFG  --NJOW03             
      WHERE o.OrderKey = @c_OrderKey     

      --NJOW04
      IF ISNULL(@c_Orderinfo02Filter,'') <> ''
      BEGIN
      	IF NOT EXISTS(SELECT 1
      	              FROM ORDERINFO(NOLOCK) 
      	              WHERE Orderkey = @c_Orderkey           
      	              AND OrderInfo02 = @c_Orderinfo02Filter)
      	BEGIN
      		GOTO NEXT_ORD
      	END                    	                    	         
      END
      
      IF @b_debug = 3
      BEGIN
         INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1,Col2, Col3, Col4, Col5)
         VALUES( 'ispAsgnTNo2a', GETDATE(), @c_OrderKey, @c_LoadKey, @b_ChildFlag, @c_TrackingNo, @c_Udef04,
               @c_ShipperKey,@c_StorerKey,'','','')                  
      END
      
           
      IF ISNULL(RTRIM(@c_Udef04),'') = '' OR (ISNULL(RTRIM(@c_Udef04),'') <> '' and @b_ChildFlag = 1) --(Wan01) 
      BEGIN  
      	 --NJOW04
      	 IF EXISTS(SELECT 1 
      	           FROM CODELKUP (NOLOCK)
      	           WHERE Listname = 'SKIPTRKNO'
      	           AND Storerkey = @c_Storerkey
      	           AND Short = @c_Shipperkey
      	           AND NOT (UDF01 = 'EXCLSKIPCHILDCTN' AND @b_ChildFlag = 1) --NJOW05
      	           AND Long = @c_ECOM_Platform)
      	 BEGIN
      	 	 GOTO NEXT_ORD
      	 END          
      	
         SET @n_Retry = 0            
         Get_NextTrackingNo:  
           
         --(Wan02) - START
         SET @c_TrackingNo = ''  
         SET @n_RowRef = 0  
         SET @c_labelNo = ''
         SELECT TOP 1   
               @c_TrackingNo = CT.TrackingNO    
            ,  @n_RowRef     = CT.RowRef 
            ,  @c_labelNo    = @c_Orderkey
         FROM CARTONTRACK CT WITH (NOLOCK)    
         WHERE CT.CarrierName = @c_ShipperKey
         AND   CT.CarrierRef2 = ''
         AND   CT.LabelNo = @c_Orderkey   
         ORDER BY CT.RowRef 
         --(Wan02) - END

         IF ISNULL(RTRIM(@c_TrackingNo), '') = ''        --(Wan02)   
         BEGIN   
            SET @c_KeyName = ''  
            SET @c_CarrierName = ''   
            SET @c_PRTFLAG = ''

            SELECT TOP 1   
                  @c_KeyName = CASE WHEN @b_childflag = 0 THEN clk.Long ELSE clk.udf05 END,              -- (Wan01)  
                  @c_CarrierName = clk.Short, @c_PRTFLAG = clk.UDF04  -- TLTING04
            FROM CODELKUP AS clk WITH (NOLOCK)  
            WHERE clk.Storerkey = @c_StorerKey   
            AND   clk.Short = @c_Shipperkey  
            AND   clk.Notes = @c_Facility   
            AND   clk.LISTNAME = 'AsgnTNo'  
            AND   clk.UDF01 = CASE WHEN ISNULL(clk.UDF01,'') <> '' THEN @c_Udef02 ELSE clk.UDF01 END  
            AND   clk.UDF02 = CASE WHEN ISNULL(clk.UDF02,'') <> '' THEN @c_Udef03 ELSE clk.UDF02 END    -- (SOS#332990)    
            AND   clk.UDF03 = CASE WHEN ISNULL(clk.UDF03,'') <> '' THEN @c_OrderType ELSE clk.UDF03 END -- (SOS#345781)    
         END 

         IF ( @c_KeyName <> '' AND @c_CarrierName <> ''  -- (SOS#345781)  
         AND  ISNULL(RTRIM(@c_TrackingNo), '')= '')      --(Wan02)
         OR ( ISNULL(RTRIM(@c_TrackingNo), '') <> '' )   --(Wan02)
         BEGIN
            IF ISNULL(RTRIM(@c_TrackingNo), '') = ''     --(Wan02)
            BEGIN 
          
               SET @c_TrackingNo = '' 
               SET @c_CarrierRef1  = ''              
               SET @n_RowRef = 0  
               SET @n_SuccessFlag = 0  
   
               -- TLTING02
               SELECT TOP 1   
                     @c_TrackingNo = CTP.TrackingNo,  
                     @n_RowRef = CTP.RowRef,  
                     @c_CarrierRef1  = CTP.CarrierRef1   
               FROM CARTONTRACK_Pool CTP WITH (NOLOCK)    
               WHERE CTP.RowRef in (  
                        Select TOP 1 CT.RowRef  
                        FROM CARTONTRACK_Pool CT WITH (NOLOCK)      
                        WHERE CT.KeyName     = @c_KeyName    
                        AND   CT.CarrierName = @c_CarrierName    
                        AND   CT.CarrierRef2 = ''     --tlting03
                        ORDER BY CT.RowRef )  


               --SELECT TOP 1 
               --      @c_TrackingNo = CT.TrackingNo,
               --      @n_RowRef = CT.RowRef,
               --      @c_CarrierRef1  = CT.CarrierRef1 
               --FROM CARTONTRACK_Pool CT WITH (NOLOCK)    
               --WHERE CT.KeyName     = @c_KeyName  
               --AND   CT.CarrierName = @c_CarrierName   
               --ORDER BY CT.RowRef            
               
               IF @b_debug=1 AND @@ROWCOUNT=0     
               BEGIN      
                  --PRINT '@c_KeyName: ' + @c_KeyName  + '  @c_CarrierName: ' + @c_CarrierName
                  INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3,
                              Step4, Step5)
                  VALUES( 'ispAsgnTNo2', GETDATE(), @c_KeyName, @c_CarrierName, @c_StorerKey, @c_Facility, @c_Shipperkey)                  
                  GOTO EXIT_SP    
               END    
            END      
            
            IF ISNULL(RTRIM(@c_TrackingNo), '') <> ''  
            BEGIN
               SET @n_SuccessFlag = 0      
                           
               DELETE FROM dbo.CartonTrack_Pool WITH (ROWLOCK)
               WHERE RowRef = @n_RowRef 
               
               SET @n_SuccessFlag = @@ROWCOUNT
                
            END               
            IF @n_SuccessFlag > 0  
            BEGIN 
               SET @n_SuccessFlag = 0
               INSERT INTO dbo.CartonTrack  
                  ( TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef1, CarrierRef2 )  
               VALUES  
                  ( @c_TrackingNo, @c_CarrierName, @c_KeyName , @c_OrderKey, @c_CarrierRef1, 'GET' )
                  
               SET @n_SuccessFlag = @@ROWCOUNT        
            END    
                       
               IF @n_SuccessFlag = 0   
               BEGIN  
                  SET @n_Retry = ISNULL(@n_Retry, 0) + 1  
                     
                  IF @n_Retry > 3   
                     GOTO EXIT_SP  
                  ELSE  
                     GOTO Get_NextTrackingNo  
               END  
               ELSE IF @b_ChildFlag = 0         -- (Wan01)  
               BEGIN  
                  -- (Shong02)  
                  -- SOS#313547 Update Courrier Role into Orders.UserDefine10  
                    
                  SET @c_CLK_UDF02 = ''  
                  SET @c_UpdateEComDstntCode = '0'  
                    
                  EXEC nspGetRight  
                     @c_Facility  = '',  
                     @c_StorerKey = @c_StorerKey,  
                     @c_sku       = '',  
                     @c_ConfigKey = 'UpdateEComDstntCode',  
                     @b_Success   = @b_Success OUTPUT,  
                     @c_authority = @c_UpdateEComDstntCode OUTPUT,  
                     @n_err       = @n_err OUTPUT,   
                     @c_errmsg    = @c_ErrMsg OUTPUT  
    
                  IF @c_UpdateEComDstntCode = '1' 
                  BEGIN  
                     SET @c_CLK_UDF02 = ''  
                       
                     SELECT @c_CLK_UDF02 = ISNULL(c.UDF02,'')   
                     FROM ORDERS o WITH (NOLOCK)  
                     JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'CourRule' 
                         AND c.[Description] = o.C_City 
                         AND c.Long = o.M_City 
                     WHERE o.OrderKey = @c_OrderKey                     
                  END  
                  ELSE IF @c_UpdateEComDstntCode = '2' -- Shong01 
                  BEGIN
                     SET @c_CLK_UDF02 = ''  
                       
                     -- Shong02 
                     IF ISNULL(RTRIM(@c_CLK_UDF02),'') = ''
                     BEGIN
                        SELECT @c_CLK_UDF02 = ISNULL(c.UDF03,'')   
                        FROM ORDERS o WITH (NOLOCK)  
                        JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'HMCS' 
                           AND c.Notes = o.C_City 
                           AND c.Notes2 = o.C_Address1 
                        WHERE o.OrderKey = @c_OrderKey 
                     END                    
                  END
                  ELSE IF @c_UpdateEComDstntCode = '3' --NJOW01
                  BEGIN
                     SET @c_CLK_UDF02 = ''  
                       
                     SELECT @c_CLK_UDF02 = ISNULL(c.UDF03,'')   
                     FROM ORDERS o WITH (NOLOCK)  
                     JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'DELPLACE' 
                        AND c.Notes = o.C_City 
                        AND c.Notes2 = o.C_Address1 
                        AND c.Storerkey = o.Storerkey
                        AND c.Short = o.Shipperkey
                     WHERE o.OrderKey = @c_OrderKey  
                     
                     IF ISNULL(@c_CLK_UDF02,'') = ''
                     BEGIN
                        SELECT @c_CLK_UDF02 = MAX(ISNULL(c.UDF03,''))
                        FROM ORDERS o WITH (NOLOCK)  
                        JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = 'DELPLACE' 
                           AND c.Notes = o.C_City 
                           AND c.Storerkey = o.Storerkey
                           AND c.Short = o.Shipperkey
                        WHERE o.OrderKey = @c_OrderKey
                        HAVING COUNT(DISTINCT c.UDF03) = 1  
                     END                  	 
                  END
                       
                  UPDATE ORDERS WITH (ROWLOCK)    
                     SET Userdefine04 = CASE WHEN (UserDefine04 IS NULL OR UserDefine04 = '')   
                                                THEN @c_TrackingNo  
                                             ELSE UserDefine04  
                                        END,  
                         TrackingNo  = CASE WHEN (TrackingNo IS NULL OR TrackingNo = '')     
                                                THEN @c_TrackingNo  
                                             ELSE TrackingNo  
                                        END,                                         
                         UserDefine10 = CASE   
                                          WHEN ISNULL(RTRIM(@c_CLK_UDF02), '') <> '' AND @c_UpdateEComDstntCode = '1'   
                                             THEN @c_CLK_UDF02  
                                          ELSE UserDefine10  
                                        END,  
                         -- SHONG01 
                         DeliveryPlace = CASE   
                                          WHEN ISNULL(RTRIM(@c_CLK_UDF02), '') <> '' AND @c_UpdateEComDstntCode IN('2','3')  --NJOW01   
                                             THEN @c_CLK_UDF02  
                                          ELSE DeliveryPlace  
                                        END,   
                         Printflag = CASE WHEN @c_PRTFLAG = 'PRTFLAG' THEN '2' ELSE Printflag  END,  --tlting04
                         PrintDocDate = CASE WHEN @c_PRTFLAG = 'PRTFLAG' THEN Getdate() ELSE PrintDocDate  END,  --tlting04
                         TrafficCop = NULL,   
                         EditDate = GETDATE(),   
                         EditWho = SUSER_NAME()      
                  WHERE ORDERKEY = @c_OrderKey   
     
                  /********************************************************/      
                  /* Interface Trigger Points Calling Process - (Start)   */      
                  /********************************************************/      
                  IF EXISTS(SELECT 1  
                            FROM  ITFTriggerConfig ITC WITH (NOLOCK)   
                            WHERE ITC.StorerKey = @c_StorerKey      
                              AND ITC.SourceTable = 'AsgnTNo'      
                              AND ITC.sValue      = '1'  
                              AND ITC.ConfigKey   = 'WSCRSOCFM2'  
                              AND itc.TargetTable = 'TRANSMITLOG3' )           
                  BEGIN  
      
                     EXEC dbo.ispGenTransmitLog3 'WSCRSOCFM2', @c_OrderKey, '', @c_StorerKey, ''      
                                       , @b_success OUTPUT      
                                       , @n_err OUTPUT      
                                       , @c_errmsg OUTPUT      
                    
                  END                                  
               END   
            -- END -- IF ISNULL(RTRIM(@c_TrackingNo), '') <> ''              
         END -- IF @c_KeyName <> '' AND @c_CarrierName <> ''  
      END -- IF ISNULL(RTRIM(@c_Udef04),'') = ''               
      
      NEXT_ORD:  --NJOW03
      
      FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey         
   END -- WHILE @@FETCH_STATUS <> -1      
     
   CLOSE CUR_ORDERKEY          
   DEALLOCATE CUR_ORDERKEY    
     
EXIT_SP:  
      
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_Success = 0      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispAsgnTNo2'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END      
      
END -- Procedure 

GO