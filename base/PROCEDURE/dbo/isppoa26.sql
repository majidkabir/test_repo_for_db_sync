SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOA26                                           */    
/* Creation Date: 27-SEP-2023                                           */    
/* Copyright: MAERSK                                                    */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-23770 - CN TRILOGY - Calculate MD5 and update to orders */  
/*          after fully allocated.                                      */
/*                                                                      */
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */   
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */ 
/* 27-SEP-2023  NJOW    1.0   Devops Combine Script                     */
/************************************************************************/    
CREATE   PROC [dbo].[ispPOA26]      
     @c_OrderKey    NVARCHAR(10) = ''   
   , @c_LoadKey     NVARCHAR(10) = ''  
   , @c_Wavekey     NVARCHAR(10) = ''  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0      
AS      
BEGIN      
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF           
      
   DECLARE  @n_Continue              INT,      
            @n_StartTCnt             INT, -- Holds the current transaction count  
            @c_RequestString         NVARCHAR(MAX),
            @c_OutputString          NVARCHAR(1000),
            @c_GetOrderkey           NVARCHAR(10),
            @c_vbErrMsg              NVARCHAR(250),
            @c_TotQty                NVARCHAR(10)
                                              
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''    
      
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN(1,2)   
   BEGIN      	
      IF ISNULL(RTRIM(@c_OrderKey), '') <> ''  
      BEGIN  
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM ORDERS O (NOLOCK)
            WHERE O.Orderkey = @c_OrderKey
            AND O.Status = '2'
      END
      ELSE IF ISNULL(RTRIM(@c_Loadkey), '') <> ''  
      BEGIN
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM LoadPlanDetail LPD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON LPD.OrderKey = O.OrderKey 
            WHERE LPD.LoadKey = @c_Loadkey
            AND O.Status = '2'
      END 
      ELSE IF ISNULL(RTRIM(@c_Wavekey), '') <> ''  
      BEGIN
         DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Orderkey
            FROM WaveDetail WD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
            WHERE WD.Wavekey = @c_Wavekey
            AND O.Status = '2'
      END 
      ELSE 
      BEGIN      
         SELECT @n_Continue = 3      
         SELECT @n_Err = 67010      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Loadkey, Wave and Orderkey are Blank (ispPOA26)'  
         GOTO EXIT_SP      
      END    
   	        
      OPEN cur_ORD    
            
      FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
        
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN      	
      	 SELECT @c_RequestString = '', @c_TotQty = '', @c_OutputString = '', @c_vbErrMsg = ''
      	
         SELECT @c_RequestString = (
            SELECT OS.SkuInv + RTRIM(LTRIM(CAST(OS.Qty AS NVARCHAR)))
            FROM (SELECT RTRIM(PD.Sku) + RTRIM(LA.Lottable02) + ISNULL(CONVERT(NVARCHAR(8), LA.Lottable04, 112),'') AS SkuInv, 
                         SUM(PD.Qty) AS Qty
                  FROM PICKDETAIL PD (NOLOCK)
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
                  WHERE PD.Orderkey = @c_GetOrderkey
                  GROUP BY RTRIM(PD.Sku) + RTRIM(LA.Lottable02) + ISNULL(CONVERT(NVARCHAR(8), LA.Lottable04, 112),'')
                 ) AS OS
            ORDER BY OS.SkuInv FOR XML PATH('')
            )              	
            
         EXEC master.dbo.isp_GetMD5Hash @c_StringEncoding = N'UTF8', -- nvarchar(30)                                                                                               
              @c_InputString = @c_RequestString, -- nvarchar(max)                                                                                                                       
              @c_OutputString = @c_OutputString OUTPUT, -- nvarchar(max)                                                                                                                
              @c_vbErrMsg = @c_vbErrMsg OUTPUT -- nvarchar(max)                                             
         
         SELECT @c_TotQty = CAST(SUM(Qty) AS NVARCHAR)
         FROM PICKDETAIL (NOLOCK)     
         WHERE Orderkey = @c_GetOrderkey

         SET @c_TotQty = RIGHT('00'+ RTRIM(LTRIM(@c_TotQty)),2)                                                                                                                       
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
         SET @c_OutputString = SUBSTRING(@c_OutputString,1,1) + SUBSTRING(@c_OutputString,5,1) + SUBSTRING(@c_OutputString,9,1) + SUBSTRING(@c_OutputString,13,1)                   
                             + SUBSTRING(@c_OutputString,17,1) + SUBSTRING(@c_OutputString,21,1) + SUBSTRING(@c_OutputString,25,1) + SUBSTRING(@c_OutputString,29,1)           
                             + @c_TotQty         
         
         IF ISNULL(@c_OutputString,'') <> ''
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET Notes2 = @c_OutputString
              , TrafficCop   = NULL
              , EditDate     = GETDATE()
              , EditWho      = SUSER_SNAME()
            WHERE OrderKey   = @c_GetOrderkey
            
            SELECT @n_err = @@ERROR
            
            IF @n_err <> 0                                                                                                                                                               
            BEGIN                                                                                                                                                                                  
               SELECT @n_Continue = 3                                                                                                                                                              
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ORDERS Failed. (ispPOA26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
            END
         END
                        
         FETCH NEXT FROM cur_ORD INTO @c_GetOrderkey     
      END  
      CLOSE cur_ORD
      DEALLOCATE cur_ORD    
   END  

EXIT_SP:        

   IF CURSOR_STATUS('LOCAL', 'cur_ORD') IN (0 , 1)
   BEGIN
      CLOSE cur_ORD
      DEALLOCATE cur_ORD   
   END 
   
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA26'      
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