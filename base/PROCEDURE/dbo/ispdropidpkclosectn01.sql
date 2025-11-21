SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispDropIDPKCLOSECTN01                               */  
/* Creation Date: 28-Aug-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-10266 SG-Logitech û Packing MRP Label                    */
/*                                                                       */  
/* Called By: Packing (isp_DropIDpackautoclosecarton_wrapper)            */  
/*            storerconfig: DropIDPackAutoCloseCarton_SP                 */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */   
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispDropIDPKCLOSECTN01]      
   @c_Dropid            NVARCHAR(20),
   @c_Storerkey         NVARCHAR(15),  
   @c_Sku               NVARCHAR(60),
   @c_SerialNoRequired  NVARCHAR(3),
   @c_SerialNo          NVARCHAR(30), 
   @c_CallSource        NVARCHAR(20),
   @c_CloseCarton       NVARCHAR(10) OUTPUT,
   @b_Success           INT      OUTPUT,
   @n_Err               INT      OUTPUT, 
   @c_ErrMsg            NVARCHAR(250) OUTPUT
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         
            @n_debug int,
            @n_cnt int,
            @c_SerialNoType    NVARCHAR(1)
                
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0
    
    SET @c_CloseCarton = '0'
    SET @c_SerialNoType = RIGHT(RTRIM(@c_SerialNo),1) 
    
    IF @n_continue IN(1,2)
    BEGIN
      IF @c_CallSource = 'SerialNo'
      BEGIN
       IF @c_SerialNoType = 'M'
       BEGIN
          SET @c_CloseCarton = '1'
       END
      END
     END
               
RETURN_SP:
    
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
       execute nsp_logerror @n_err, @c_errmsg, "ispDropIDPKCLOSECTN01"  
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
 END --sp end

GO