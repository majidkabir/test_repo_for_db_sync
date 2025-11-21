SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispAsgnTNo                                         */    
/* Creation Date: 13-Nov-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* PVCS Version: 2.2                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */    
/* 13-11-2013   Shong   1.0   Initial Version                           */    
/* 16-04-2014   Shong   1.1   SQL 2012 RaiseError Function Change       */  
/* 11-06-2014   Shong   1.2   SOS#313547 Update Courrier Role into      */  
/*                            Orders.UserDefine10 (Shong02)             */  
/* 29-Sep-2014  Shong   1.3   SOS#321705 New Tracking No Extract Role   */  
/* 11-Oct-2014  Shong   1.4   Add Trigger point for transmitlog3        */  
/* 02-Dec-2014  Shong   1.5   Initialise Variable                       */  
/* 25-Feb-2015  Shong   1.6   SOS#332990 Default Orders.UserDefine03    */  
/* 27-May-2015  Shong   1.7   Performance Tuning                        */
/* 23-Jun-2015  Shong   1.8   SOS#345781 Erke Project                   */
/* 21-Sep-2015  Shong01 1.9   SOS#353089 CN_H&M(Ecom) Assign Tracking No*/
/* 21-Oct-2015  Shong02 2.0   SOS#353089 Use Different ListName         */
/* 21-JUN-2017  Wan01   2.1   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/* 21-JUN-2017  Wan02   2.2   WMS-2306 - CN-Nike SDC WMS ECOM Packing CR*/
/* 23-Oct-2017  TLTING  2.3   Update TrackingNo                         */
/************************************************************************/    
CREATE PROC [dbo].[ispAsgnTNo]      
     @c_OrderKey    NVARCHAR(10)    
   , @c_LoadKey     NVARCHAR(10)  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0  
   , @b_ChildFlag   INT = 0                     --(Wan01)
   , @c_TrackingNo  NVARCHAR(20) = '' OUTPUT    --(Wan01)      
AS      
BEGIN      
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
      

   DECLARE  @n_Continue    INT,      
            @n_StartTCnt   INT, -- Holds the current transaction count  
            @n_Retry       INT,        
            @c_Udef04      NVARCHAR(80),   
            --@c_TrackingNo  NVARCHAR(20),      --(Wan01)
            @n_RowRef      INT,   
            @c_StorerKey   NVARCHAR(15), -- (shong02)  
            @c_Udef02      NVARCHAR(20),  
            @c_Udef03      NVARCHAR(20), -- (SOS#332990)  
            @c_OrderType   NVARCHAR(10)  -- (SOS#345781) 
 
  
   DECLARE @c_KeyName      NVARCHAR(30)  
          ,@c_Facility     NVARCHAR(5)  
          ,@c_Shipperkey   NVARCHAR(15)  
          ,@c_CarrierName  NVARCHAR(30)  
          ,@c_labelNo      NVARCHAR(20)  --(Wan02)
  
   DECLARE @c_CLK_UDF02           NVARCHAR(30)  
         , @c_UpdateEComDstntCode CHAR(1)  
  
                            
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0    
   SELECT @c_ErrMsg=''    
      
   IF @n_Continue=1 OR @n_Continue=2      
   BEGIN      
      IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') = ''  
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63500      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name is Blank (ispAsgnTNo)'  
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
   END  
   ELSE  
   BEGIN  
      DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT lpd.OrderKey   
      FROM LoadplanDetail AS lpd WITH (NOLOCK) 
      JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey       
      WHERE lpd.LoadKey = @c_LoadKey        
      AND   o.ShipperKey IS NOT NULL 
      AND   o.ShipperKey <> ''
   END  
     
   OPEN CUR_ORDERKEY      
  
   FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey       
    
   WHILE @@FETCH_STATUS <> -1          
   BEGIN         
      IF @b_debug=1      
      BEGIN      
         PRINT @c_OrderKey         
      END      
  
      SET @c_Udef04 = ''  
      SET @c_StorerKey = ''  
      SET @c_ShipperKey = ''  
      SET @c_Facility = ''  
      SET @c_Udef02 = ''  
      SET @c_Udef03 = ''    -- (SOS#332990)
      SET @c_OrderType = '' -- (SOS#345781)    
        
      SELECT @c_Udef04     = ISNULL(o.UserDefine04,''),   
             @c_StorerKey  = o.StorerKey,   
             @c_ShipperKey = ISNULL(o.ShipperKey,''),   
             @c_Facility   = o.Facility,  
             @c_Udef02     = ISNULL(o.UserDefine02,''),  
             @c_Udef03     = ISNULL(o.UserDefine03,''), -- (SOS#332990)  
             @c_OrderType  = ISNULL(o.[Type], '') 
      FROM ORDERS o WITH (NOLOCK)  
      WHERE o.OrderKey = @c_OrderKey     
       
      IF ISNULL(RTRIM(@c_Udef04),'') = '' OR (ISNULL(RTRIM(@c_Udef04),'') <> '' and @b_ChildFlag = 1) --(Wan01) 
      BEGIN 

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
         BEGIN                                           --(Wan02)   
            SET @c_KeyName = ''  
            SET @c_CarrierName = ''  
    
            SELECT TOP 1   
                  @c_KeyName = CASE WHEN @b_childflag = 0 THEN clk.Long ELSE clk.udf05 END,              -- (Wan01)  
                  @c_CarrierName = clk.Short  
            FROM CODELKUP AS clk WITH (NOLOCK)  
            WHERE clk.Storerkey = @c_StorerKey   
            AND   clk.Short = @c_Shipperkey  
            AND   clk.Notes = @c_Facility   
            AND   clk.LISTNAME = 'AsgnTNo'  
            AND   clk.UDF01 = CASE WHEN ISNULL(clk.UDF01,'') <> '' THEN @c_Udef02 ELSE clk.UDF01 END  
            AND   clk.UDF02 = CASE WHEN ISNULL(clk.UDF02,'') <> '' THEN @c_Udef03 ELSE clk.UDF02 END    -- (SOS#332990)  
            AND   clk.UDF03 = CASE WHEN ISNULL(clk.UDF03,'') <> '' THEN @c_OrderType ELSE clk.UDF03 END -- (SOS#345781)  
         END                                             --(Wan02)

         IF ( @c_KeyName <> '' AND @c_CarrierName <> ''  -- (SOS#345781)  
         AND  ISNULL(RTRIM(@c_TrackingNo), '')= '')      --(Wan02)
         OR ( ISNULL(RTRIM(@c_TrackingNo), '') <> '' )   --(Wan02)
         BEGIN
            IF ISNULL(RTRIM(@c_TrackingNo), '') = ''     --(Wan02)
            BEGIN 
               SELECT TOP 1   
                     @c_TrackingNo = CT.TrackingNO,    
                     @n_RowRef     = CT.RowRef  
               FROM CARTONTRACK CT WITH (NOLOCK)    
               WHERE (CT.KeyName = @c_KeyName)  
               AND   (CT.CarrierName = @c_CarrierName)
               AND   CT.CarrierRef2 = ''
               AND   CT.LabelNo = ''   
               --AND   (CT.CarrierRef2 IS NULL OR CT.CarrierRef2 = '')    
               --AND   (LabelNo IS NULL OR LabelNo = '')            
               ORDER BY CT.RowRef   
            END   

            IF ISNULL(RTRIM(@c_TrackingNo), '') <> ''    
            BEGIN  
               UPDATE CARTONTRACK WITH (ROWLOCK)    
               SET LabelNo = @c_OrderKey, CarrierRef2 = 'GET', EditDate = GETDATE(), EditWho = SUSER_NAME()      
               WHERE RowRef = @n_RowRef  
               AND (CarrierRef2 = '')
               AND (LabelNo = @c_labelNo)                --(Wan02)
               --AND (LabelNo = '')                      --(Wan02)
               --AND (CarrierRef2 IS NULL OR CarrierRef2 = '')    
               --AND (LabelNo IS NULL OR LabelNo = '')   
     
               IF @@ROWCOUNT = 0   
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
                                          WHEN ISNULL(RTRIM(@c_CLK_UDF02), '') <> '' AND @c_UpdateEComDstntCode = '2'   
                                             THEN @c_CLK_UDF02  
                                          ELSE DeliveryPlace  
                                        END,   
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
            END -- IF ISNULL(RTRIM(@c_TrackingNo), '') <> ''              
         END -- IF @c_KeyName <> '' AND @c_CarrierName <> ''  
 
      END -- IF ISNULL(RTRIM(@c_Udef04),'') = ''               
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispAsgnTNo'      
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