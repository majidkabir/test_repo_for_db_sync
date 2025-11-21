SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPRPPLPO05                                            */
/* Creation Date: 14-Jan-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-18677 - CN IKEA Safety qty missing setup email alert    */
/*                      when populate PO                                */
/*        :                                                             */
/* Called By:  isp_PrePopulatePO_Wrapper (PrePopulatePOSP)              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 14-Jan-2022  NJOW      1.0 DEVOPS combine script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispPRPPLPO05]
           @c_Receiptkey      NVARCHAR(10)
         , @c_POKeys          NVARCHAR(MAX)
         , @c_POLineNumbers   NVARCHAR(MAX) = ''
         , @b_Success         INT OUTPUT    
         , @n_Err             INT OUTPUT
         , @c_Errmsg          NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt           INT
          ,@n_Continue            INT
          ,@n_debug               INT  
          ,@c_Storerkey           NVARCHAR(15)
          ,@c_Sku                 NVARCHAR(20)
          ,@c_Facility            NVARCHAR(5)
          ,@c_Lottable02          NVARCHAR(18)
          ,@c_UserName            NVARCHAR(128)
                             
   DECLARE @c_Body                NVARCHAR(MAX),          
           @c_Subject             NVARCHAR(255),          
           @c_Date                NVARCHAR(20),           
           @c_SendEmail           NVARCHAR(1),
           @c_Recipients          NVARCHAR(2000) 
           
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @n_debug = 0
   
   IF @n_continue IN(1,2)
   BEGIN
   	  IF CHARINDEX('|',@c_POKeys) > 0
   	     SELECT @c_POKeys = REPLACE(@c_POKeys,'|',',')    

   	  IF CHARINDEX('|',@c_POLineNumbers) > 0
   	     SELECT @c_POLineNumbers = REPLACE(@c_POLineNumbers,'|',',')       	  
   	  
      CREATE TABLE #PREPPL_PO
         (  SeqNo          INT
         ,  POKey          NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  POLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
         )
      
      INSERT INTO #PREPPL_PO
         (  SeqNo
         ,  POKey 
         )     
      SELECT SeqNo
         ,   ColValue
      FROM dbo.fnc_DelimSplit (',', @c_POKeys)
         
      IF @c_POLineNumbers <> ''
      BEGIN
         UPDATE #PREPPL_PO
         SET POLineNumber = ColValue
         FROM dbo.fnc_DelimSplit (',', @c_POLineNumbers) T
         WHERE #PREPPL_PO.SeqNo = T.SeqNo
      END      
   END
               
   IF  @n_continue IN(1,2)
   BEGIN   	                                          
   	  DECLARE CUR_Facility CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT 'KSE01'
   	        UNION ALL
   	     SELECT 'GIK01'
   	        UNION ALL
   	     SELECT 'BJE01'

      OPEN CUR_Facility              
        
      FETCH NEXT FROM CUR_Facility INTO @c_Facility   	     
      
      WHILE @@FETCH_STATUS <> -1       
      BEGIN                    	    
      	 SET @c_Recipients = ''   	                    
   	     SET @c_SendEmail ='N'
         SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
         SET @c_Subject = 'Lake of safety qty Skus - ' + @c_Date + ' Facility: ' + RTRIM(@c_Facility)  
         
         SET @c_Body = '<style type="text/css">       
                  p.a1  {  font-family: Arial; font-size: 12px;  }      
                  table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
                  table, td, th {padding:3px; font-size: 12px; }
                  td { vertical-align: top}
                  </style>'
         
         SET @c_Body = @c_Body + '<b>Please setup safety qty for sku below.</b>'  
         SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
         SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Faciliity</th><th>Storerkey</th><th>ASN</th><th>Sku</th><th>Lottable02</th><th>AddWho</th></tr>'  
         
         DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PO.Storerkey, POD.Sku, POD.Lottable02, POD.Facility, Suser_Sname()
            FROM PO (NOLOCK)
            JOIN PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
            LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'IKEAFPSKU' AND CL.Code2 = POD.Facility AND CL.Code = POD.Sku
            WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
            AND POD.Userdefine04 = 'FULL'
            AND CL.Code IS NULL
            AND POD.Facility = @c_Facility
            ORDER BY PO.Storerkey, POD.Facility, POD.Sku, POD.Lottable02
           
         OPEN CUR_SKU              
           
         FETCH NEXT FROM CUR_SKU INTO @c_Storerkey, @c_Sku, @c_Lottable02, @c_Facility, @c_UserName
         
         SELECT TOP 1 @c_Recipients = Notes
         FROM CODELKUP (NOLOCK)
         WHERE Listname = 'EMAILALERT'
         AND Storerkey = @c_Storerkey
         AND Code = 'ispPRPPLPO05'
         AND Code2 = @c_Facility
         
         IF ISNULL(@c_Recipients,'') = '' AND @c_Facility = 'KSE01'
            SET @c_Recipients = 'IKEASHACPU@LFLogistics.com'
         ELSE IF ISNULL(@c_Recipients,'') = '' AND @c_Facility = 'GIK01'
            SET @c_Recipients = 'LFLGUZIKEAWH@LFLogistics.com'
         ELSE IF ISNULL(@c_Recipients,'') = '' AND @c_Facility = 'BJE01'
            SET @c_Recipients = 'LFLBeijingIKEACPU@LFLogistics.com'
           
         WHILE @@FETCH_STATUS <> -1       
         BEGIN           
            SET @c_SendEmail = 'Y'
              
            SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_Facility) + '</td>'  
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Storerkey) + '</td>'  
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Receiptkey) + '</td>'  
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Sku) + '</td>'  
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable02) + '</td>'  
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_UserName) + '</td>'  
            SET @c_Body = @c_Body + '</tr>'  
                                               
            FETCH NEXT FROM CUR_SKU INTO @c_Storerkey, @c_Sku, @c_Lottable02, @c_Facility, @c_UserName
         END  
         CLOSE CUR_SKU              
         DEALLOCATE CUR_SKU           
           
         SET @c_Body = @c_Body + '</table>'  
         
         IF @c_SendEmail = 'Y'
         BEGIN           
            EXEC msdb.dbo.sp_send_dbmail   
                  @recipients      = @c_Recipients,  
                  @copy_recipients = NULL,  
                  @subject         = @c_Subject,  
                  @body            = @c_Body,  
                  @body_format     = 'HTML' ;  
                    
            SET @n_Err = @@ERROR  
            
            IF @n_Err <> 0  
            BEGIN           
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 83010
   	           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Executing sp_send_dbmail alert Failed! (ispPRPPLPO05)' + ' ( '
                              + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END  
         END     
         
         FETCH NEXT FROM CUR_Facility INTO @c_Facility   	     
      END      
      CLOSE CUR_Facility
      DEALLOCATE CUR_Facility 	
   END                  
  
QUIT_SP:
  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRPPLPO05'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO