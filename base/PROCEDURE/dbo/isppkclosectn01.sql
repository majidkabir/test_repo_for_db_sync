SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispPKCLOSECTN01                                     */  
/* Creation Date: 08-Aug-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5729 CN Puma Auto close carton                           */
/*                                                                       */  
/* Called By: Packing (isp_packautoclosecarton_wrapper)                  */  
/*            storerconfig: PackAutoCloseCarton_SP                       */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 27-Jan-2021 Wan01    1.1   WMS-16079 - RG - LEGO - EXCEED Packing    */   
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispPKCLOSECTN01]      
   @c_PickSlipNo  NVARCHAR(10),
   @c_Storerkey   NVARCHAR(15),  
   @c_ScanSkuCode NVARCHAR(50),
   @c_Sku         NVARCHAR(20),  
   @c_CloseCarton NVARCHAR(10) OUTPUT,
   @b_Success     INT      OUTPUT,
   @n_Err         INT      OUTPUT, 
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @n_CartonNo    INT          = 0,          -- Add default @n_CartonNo to SP 
   @c_ScanColumn  NVARCHAR(50) = '',         -- Add default @c_ScanColumn to SP
   @n_Qty         INT          = 0           -- Add default @n_Qty to SP  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         
            @n_debug int,
            @n_cnt int
                
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0
    
    SET @c_CloseCarton = 'N'
    
    IF @n_continue IN(1,2)
    BEGIN
       IF LEN(RTRIM(@c_ScanSkuCode)) = 16
       BEGIN
           IF EXISTS(SELECT 1 FROM UPC (NOLOCK) WHERE UPC = @c_ScanSkuCode AND StorerKey = @c_Storerkey)
           BEGIN
             SET @c_CloseCarton = 'Y'
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
       execute nsp_logerror @n_err, @c_errmsg, "ispPKCLOSECTN01"  
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