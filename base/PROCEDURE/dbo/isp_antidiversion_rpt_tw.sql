SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_antidiversion_rpt_tw                           */
/* Creation Date: 16-Oct-2017                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-2952 [TW-LOR] RCM: Print Anti Diversion Label          */
/*                                                                      */
/* Usage:  Call from r_dw_antidiversion_rpt_tw                          */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_antidiversion_rpt_tw] 
      (@c_labeltype  NVARCHAR(50)
      ,@c_brandcode  NVARCHAR(30)
      ,@c_printcount NVARCHAR(30) 
      ,@c_storerkey  NVARCHAR(20)
      )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTranCount  INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_ErrMsg          NVARCHAR(255) 

  
  DECLARE @c_PickHeaderkey      NVARCHAR(18)   
         ,@n_copy               INT            
         ,@c_UDF03              NVARCHAR(20)
         ,@c_UDF02              NVARCHAR(20)  
         ,@c_value              NVARCHAR(20) 
         ,@n_startNo            INT
   
         
   SET @n_StartTranCount= @@TRANCOUNT
   SET @n_Continue      = 1
   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_ErrMsg        = ''
   SET @c_PickHeaderkey = ''      
   SET @n_copy          = 1       
   SET @c_UDF03         = ''
   SET @c_UDF02         = ''
   
   
   IF CAST(ISNULL(@c_printcount,'0') AS INT) > 1
   BEGIN
   	SET @n_copy = CAST(@c_printcount AS INT)
   END 
  
  CREATE TABLE #TEMP_AntiDiv_Rpt (
   ID        [INT] IDENTITY(1,1) NOT NULL
  ,VALUE     NVARCHAR(10)
  ,labeltype NVARCHAR(50)  NULL
  ,brandcode  NVARCHAR(30) NULL
  ,printcount NVARCHAR(30) NULL
  ,storerkey  NVARCHAR(20) NULL 
   )
  
    SELECT @c_UDF03 = UDF03
           ,@c_UDF02 = UDF02
    FROM CODELKUP WITH (NOLOCK)
    WHERE Listname = 'serialno'
    AND code = @c_labeltype + @c_brandcode
    AND storerkey=@c_storerkey
    
    IF ISNULL(@c_UDF03,'') = '' OR @c_UDF03 = '0000000'
    BEGIN
    	SET @n_startNo = 1 	
    END
    ELSE
    BEGIN
    	SET @n_startNo = CAST(@c_UDF03 AS INT) + 1
    END	
    
    WHILE @n_copy >= 1
    BEGIN
    	
    	SET @c_value = ''
    	SET @c_value = @c_brandcode + right('000000'+convert(varchar(7), @n_startNo), 7) + @c_labeltype
    	
    	INSERT INTO #TEMP_AntiDiv_Rpt (VALUE,labeltype,brandcode, printcount,
    	            storerkey)
    	VALUES(@c_value,@c_labeltype,@c_brandcode,@c_printcount,@c_storerkey)
    	
    	SET @n_copy = @n_copy - 1
    	SET @n_startNo = @n_startNo + 1
    END
  
   SELECT VALUE,labeltype,brandcode, printcount,
    	            storerkey
   FROM #TEMP_AntiDiv_Rpt
   
  
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCount
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_antidiversion_rpt_tw'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO