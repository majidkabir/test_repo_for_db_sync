SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_PrintPackingList18                              */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: RCM report prompt before print                              */
/*                                                                      */
/* Called By: isp_printprompt                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintPackingList18] 
   @c_Storerkey   NVARCHAR(15), 
   @c_reporttype  NVARCHAR(10), 
   @c_datawindowname NVARCHAR(40), 
   @c_parameter01   NVARCHAR(100), 
   @c_parameter02   NVARCHAR(100), 
   @c_parameter03   NVARCHAR(100), 
   @c_parameter04   NVARCHAR(100), 
   @c_parameter05   NVARCHAR(100), 
   @c_promptmessage   NVARCHAR(2000) OUTPUT, 
   @b_success   INT OUTPUT, 
   @n_err       INT OUTPUT, 
   @c_errmsg  NVARCHAR(250) OUTPUT 
AS 
BEGIN
	 DECLARE @c_short_type NVARCHAR(10),
	         @c_udf01_spname NVARCHAR(60),
	         @c_notes_prnprompt NVARCHAR(2000),
	         @n_cnt INT,
	         @cSQL NVARCHAR(2000),
            @c_orderkey  NVARCHAR(10)
	         
	 SELECT @b_success = 0, @n_err = 0, @c_errmsg = '', @c_notes_prnprompt = '', @cSQL = ''
	 
    SELECT TOP 1 @c_Orderkey = PH.Orderkey 
        FROM PACKHEADER PH WITH (NOLOCK)
        WHERE PH.PickSlipNo = @c_parameter01


    IF EXISTS (SELECT 1 FROM CODELKUP C WITH (NOLOCK)
                        JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Type = C.Code AND ORD.STORERKEY = C.Storerkey
               WHERE C.Listname = 'PrtPKList' AND UDF01='Y')

    BEGIN
     
    SELECT TOP 1 @c_notes_prnprompt = Notes
	 FROM CODELKUP (NOLOCK)
	 WHERE Listname = 'PRNPROMPT'
	 AND Storerkey = @c_Storerkey
	 AND Code = @c_reporttype
	 AND Long = @c_datawindowname	
     
     SET @c_promptmessage = @c_notes_prnprompt
     SET @b_success   = 1
       
    END       
	    
   QUIT:

   IF @n_Err <> 0      
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PrintPrompt'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END                
END

GO