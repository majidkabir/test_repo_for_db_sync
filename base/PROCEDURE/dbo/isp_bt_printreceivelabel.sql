SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_BT_PrintReceiveLabel                            */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 352700-RCM print bartender label                            */
/*                                                                      */
/* Called By: nep_n_cst_print_util                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 07-Mar-2016  CSCHONG   1.0   Change labeltype (CS01)                 */
/************************************************************************/

CREATE PROC [dbo].[isp_BT_PrintReceiveLabel] 
   @c_Parm01        NVARCHAR(100) = '', 
   @c_Parm02        NVARCHAR(100) = '', 
   @c_Parm03        NVARCHAR(100) = '', 
   @b_success       INT = 0 OUTPUT , 
   @n_err           INT = 0 OUTPUT, 
   @c_errmsg        NVARCHAR(250) = '' OUTPUT 
AS 
BEGIN
	 DECLARE @n_cnt       INT,
            @n_continue  INT,
	         @cSQL        NVARCHAR(2000),
            @c_UserId    NVARCHAR(30),
            @c_PrinterID NVARCHAR(10),
            @c_LabelType NVARCHAR(30),
            @c_NoOfCopy  NVARCHAR(5),
            @c_id        NVARCHAR(18),
            @n_MaxCount  INT,
            @c_receiptline NVARCHAR(100)

    Declare    @c_Parm04        NVARCHAR(100) , 
               @c_Parm05        NVARCHAR(100) ,
               @c_Parm06        NVARCHAR(100) , 
               @c_Parm07        NVARCHAR(100) , 
               @c_Parm08        NVARCHAR(100) , 
               @c_Parm09        NVARCHAR(100) , 
               @c_Parm10        NVARCHAR(100) 
	         
	 SELECT @b_success = 1, @n_err = 0, @c_errmsg = '',  @cSQL = ''
    SET @c_NoOfCopy = '1'
    SET @c_LabelType = 'PALLETLBLASRS'           --CS01
    SET @c_id = ''
    SET @n_MaxCount = 1

    SET   @c_Parm04    =    ''
    SET   @c_Parm05    =    ''
    SET   @c_Parm06    =    ''
    SET   @c_Parm07    =    ''
    SET   @c_Parm08    =    ''
    SET   @c_Parm09    =    ''
    SET   @c_Parm10    =    ''
  
    SET @c_userid = SUSER_SNAME() 
    
    SELECT @c_PrinterID = defaultprinter
    FROM rdt.rdtuser WITH (NOLOCK)
    WHERE username = @c_UserId

    IF ISNULL(@c_Parm02,'') = '' OR @c_Parm02 ='0'
    BEGIN
     SET @c_Parm02 = ''
     SET @c_Parm03 = ''
     SET @c_Parm04 = '' 

     EXEC isp_BT_GenBartenderCommand        
          @cPrinterID = @c_PrinterID  
         ,@c_LabelType = @c_LabelType  
         ,@c_userid = @c_UserId  
         ,@c_Parm01 = @c_Parm01  
         ,@c_Parm02 = @c_Parm02  
         ,@c_Parm03 = @c_Parm03
         ,@c_Parm04 = @c_Parm04  
         ,@c_Parm05 = @c_Parm05  
         ,@c_Parm06 = @c_Parm06  
         ,@c_Parm07 = @c_Parm07  
         ,@c_Parm08 = @c_Parm08  
         ,@c_Parm09 = @c_Parm09  
         ,@c_Parm10 = @c_Parm10  
         ,@c_Storerkey = ''  
         ,@c_NoCopy = @c_NoOfCopy  
         ,@c_Returnresult = 'Y'   
         ,@n_err = @n_Err OUTPUT  
         ,@c_errmsg = @c_ErrMsg OUTPUT      
  
      IF @n_err <> 0  
      BEGIN  
          SELECT @n_continue = 3    
          GOTO QUIT_SP  
      END
     GOTO QUIT_SP
    END
    ELSE
    BEGIN
     SELECT  @c_id =  toid 
     FROM RECEIPTDETAIL WITH (NOLOCK)
     WHERE RECEIPTKEY = @c_parm01
     AND RECEIPTLineNumber = @c_Parm02
  
     SELECT @n_MaxCount = COUNT(1)
     FROM RECEIPTDETAIL WITH (NOLOCK)
     WHERE RECEIPTKEY = @c_parm01 
     AND ToID =  @c_id

     SET @c_Parm03 = ''
     SET @c_Parm04 = '' 
 
    GOTO DETAIL
    END 

   --select 'toid',@c_id

    -- WHILE  @n_MaxCount <> 0
   --  BEGIN
  
   DETAIL:
   BEGIN

   DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT RECEIPTLINENUMBER   
   FROM  RECEIPTDETAIL RECDET WITH (NOLOCK)
   WHERE RECEIPTKEY =  @c_parm01 
   --AND Receiptlinenumber = CASE WHEN ISNULL(@c_Parm02,'') = '' THEN RECDET.receiptlinenumber ELSE @c_Parm02 END
   AND TOID =  @c_id 
  
   OPEN CUR_RECEIPTDETAIL   
     
   FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @c_receiptline    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

      EXEC isp_BT_GenBartenderCommand        
          @cPrinterID = @c_PrinterID  
         ,@c_LabelType = @c_LabelType  
         ,@c_userid = @c_UserId  
         ,@c_Parm01 = @c_Parm01  
         ,@c_Parm02 = @c_receiptline  
         ,@c_Parm03 = @c_Parm03
         ,@c_Parm04 = @c_Parm04  
         ,@c_Parm05 = @c_Parm05  
         ,@c_Parm06 = @c_Parm06  
         ,@c_Parm07 = @c_Parm07  
         ,@c_Parm08 = @c_Parm08  
         ,@c_Parm09 = @c_Parm09  
         ,@c_Parm10 = @c_Parm10  
         ,@c_Storerkey = ''  
         ,@c_NoCopy = @c_NoOfCopy  
         ,@c_Returnresult = 'Y'   
         ,@n_err = @n_Err OUTPUT  
         ,@c_errmsg = @c_ErrMsg OUTPUT      
  
      IF @n_err <> 0  
      BEGIN  
          SELECT @n_continue = 3    
          GOTO QUIT_SP  
      END

   FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @c_receiptline   
   END   
        
   CLOSE CUR_RECEIPTDETAIL            
   DEALLOCATE CUR_RECEIPTDETAIL   
  END
    --   SET @n_MaxCount = @n_MaxCount - 1

   --END
   QUIT_SP:
   
   --SELECT @c_promptmessage = @c_notes_prnprompt
   
   IF @n_continue = 3      
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BT_PrintReceiveLabel'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END                
END

GO