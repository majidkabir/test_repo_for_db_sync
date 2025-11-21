SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPreMBOLShipWrapper                              */  
/* Creation Date: 17-May-2023                                           */  
/* Copyright: MAERSK                                                    */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-22541 - PreMBOLShipSP                                   */  
/*                                                                      */  
/* Called By: isp_ShipMBOL                                              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 17-May-2023  WLChooi 1.0   DevOps Combine Script                     */
/************************************************************************/  
CREATE   PROC [dbo].[ispPreMBOLShipWrapper]    
     @c_MBOLKey     NVARCHAR(10)  
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue    INT     
         ,  @n_StartTCnt   INT  -- Holds the current transaction count     
  
   DECLARE  @c_SQL            NVARCHAR(MAX)      
         ,  @c_SQLParm        NVARCHAR(MAX)  
         ,  @c_PreMBOLShipSP  NVARCHAR(50)
         ,  @c_Storerkey      NVARCHAR(15)    
    
   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  ''  
 
   DECLARE CUR_MBOLSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey
   FROM MBOLDETAIL MD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   WHERE MD.MBOLKey = @c_MBOLkey
  
   OPEN CUR_MBOLSTORER  
  
   FETCH NEXT FROM CUR_MBOLSTORER INTO @c_Storerkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      SET @c_PreMBOLShipSP = ''
                                  
      EXEC nspGetRight  
           @c_Facility  = NULL,  
           @c_StorerKey = @c_StorerKey,  
           @c_sku       = NULL,  
           @c_ConfigKey = 'PreMBOLShipSP',   
           @b_Success   = @b_Success                  OUTPUT,  
           @c_authority = @c_PreMBOLShipSP            OUTPUT,   
           @n_err       = @n_err                      OUTPUT,   
           @c_errmsg    = @c_errmsg                   OUTPUT  


      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreMBOLShipSP AND TYPE = 'P')
      BEGIN
         BEGIN TRAN

         SET @c_SQL = N'  
            EXECUTE ' + @c_PreMBOLShipSP + CHAR(13) +  
            '  @c_MBOLKey  = @c_MBOLKey '    + CHAR(13) +  
            ', @c_Storerkey= @c_StorerKey '  + CHAR(13) + 
            ', @b_Success  = @b_Success     OUTPUT ' + CHAR(13) + 
            ', @n_Err      = @n_Err         OUTPUT ' + CHAR(13) +  
            ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  


         SET @c_SQLParm =  N'@c_MBOLKey   NVARCHAR(10), ' + 
                            '@c_StorerKey NVARCHAR(15), ' +   
                            '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT '         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_MBOLKey, @c_StorerKey,
                            @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 
        
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3    
            SET @n_Err      = 63502    
            SET @c_ErrMsg   = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PreMBOLShipSP +   
                              CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPreMBOLShipWrapper)'
            GOTO EXIT_SP                          
         END 

         COMMIT TRAN
      END

      FETCH NEXT FROM CUR_MBOLSTORER INTO @c_Storerkey 
   END
   CLOSE CUR_MBOLSTORER
   DEALLOCATE CUR_MBOLSTORER 

EXIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_MBOLSTORER') in (0 , 1)
   BEGIN
      CLOSE CUR_MBOLSTORER
      DEALLOCATE CUR_MBOLSTORER   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPreMBOLShipWrapper'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      RETURN    
   END      
END -- Procedure  

GO