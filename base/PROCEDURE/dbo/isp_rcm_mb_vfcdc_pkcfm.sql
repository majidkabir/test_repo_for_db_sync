SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_RCM_MB_VFCDC_PKCFM                             */  
/* Creation Date: 04-Jan-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-666 CN-VFCDC Send pack confirm transmitlog3             */  
/*                                                                      */  
/* Called By: MBOL Dymaic RCM configure at listname 'RCMConfig'         */   
/*                                                                      */  
/* Parameters:                                                          */  
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
  
CREATE PROCEDURE [dbo].[isp_RCM_MB_VFCDC_PKCFM]  
   @c_Mbolkey NVARCHAR(10),     
   @b_success  int OUTPUT,  
   @n_err      int OUTPUT,  
   @c_errmsg   NVARCHAR(225) OUTPUT,  
   @c_code     NVARCHAR(30)=''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue int,  
           @n_cnt int,  
           @n_starttcnt int  
             
   DECLARE @c_Facility NVARCHAR(5),  
           @c_storerkey NVARCHAR(15),
           @c_Orderkey NVARCHAR(10),
           @n_ordcompletesendcnt INT,
           @n_ordpendingsendcnt INT,
           @n_ordnotpackcnt INT,
    		   @n_ordertypecnt INT    
                
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   SELECT @n_ordcompletesendcnt = 0, @n_ordpendingsendcnt = 0, @n_ordnotpackcnt = 0, @n_ordertypecnt = 0
             
   SELECT MD.Orderkey,
          O.Status, 
          O.Storerkey,
    		  O.Type,
          CASE WHEN ISNULL(TL3.Transmitlogkey,'') <> '' THEN '9' ELSE '0' END AS SendStatus
   INTO #TMP_ORDERS
   FROM MBOLDETAIL MD(NOLOCK)
   JOIN ORDERS O(NOLOCK) ON MD.Orderkey = O.Orderkey
   LEFT JOIN TRANSMITLOG3 TL3(NOLOCK) ON MD.Orderkey = TL3.Key1 AND TL3.key3 = O.Storerkey AND TL3.TableName = 'PACKORDLOG'
   WHERE MD.Mbolkey = @c_Mbolkey

   SELECT @n_ordcompletesendcnt = ISNULL(SUM(CASE WHEN Sendstatus = '9' THEN 1 ELSE 0 END),0),
          @n_ordpendingsendcnt = ISNULL(SUM(CASE WHEN Status >= '5' AND Sendstatus = '0' THEN 1 ELSE 0 END),0),
          @n_ordnotpackcnt = ISNULL(SUM(CASE WHEN Status < '5' AND Sendstatus = '0' THEN 1 ELSE 0 END),0),
   		    @n_ordertypecnt = ISNULL(SUM(CASE WHEN TYPE NOT LIKE '%-V%' THEN 1 ELSE 0 END),0) 
   FROM #TMP_ORDERS
   
   IF @n_ordertypecnt > 0
   BEGIN
   	   SELECT @n_continue = 3 
   	   SELECT @n_err = 60095
   	   SELECT @c_errmsg = 'Fond some orders not virtual order . Not allow to send. (isp_RCM_MB_VFCDC_PKCFM)' 
   	   GOTO ENDPROC
   END
      
   IF @n_ordpendingsendcnt > 0 AND @n_ordnotpackcnt > 0
   BEGIN
   	   SELECT @n_continue = 3 
   	   SELECT @n_err = 60096
   	   SELECT @c_errmsg = 'Fond some orders not yet pack. Not allow to send. (isp_RCM_MB_VFCDC_PKCFM)' 
   	   GOTO ENDPROC
   END
   
   IF @n_ordcompletesendcnt > 0 AND @n_ordpendingsendcnt = 0
   BEGIN
   	   SELECT @n_continue = 3 
   	   SELECT @n_err = 60097
   	   SELECT @c_errmsg = 'No send. All packed orders were sent before. (isp_RCM_MB_VFCDC_PKCFM)' 
   	   GOTO ENDPROC
   END

   IF @n_ordcompletesendcnt = 0 AND @n_ordpendingsendcnt = 0
   BEGIN
   	   SELECT @n_continue = 3 
   	   SELECT @n_err = 60098
   	   SELECT @c_errmsg = 'No packed order found to send. (isp_RCM_MB_VFCDC_PKCFM)' 
   	   GOTO ENDPROC
   END
   
   DECLARE cur_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey, Storerkey
      FROM #TMP_ORDERS
      WHERE Status >= '5'
      AND SendStatus = '0'
      ORDER BY Orderkey
    
   OPEN cur_Orders  
   FETCH NEXT FROM cur_Orders INTO @c_Orderkey, @c_Storerkey
   
   WHILE @@FETCH_STATUS = 0  
   BEGIN           	         
      EXEC dbo.ispGenTransmitLog3 'PACKORDLOG', @c_Orderkey, '', @c_StorerKey, ''    
           , @b_success OUTPUT    
           , @n_err OUTPUT    
           , @c_errmsg OUTPUT    
             
      IF @b_success = 0  
      BEGIN
   	     SELECT @n_continue = 3 
   	     SELECT @n_err = 60099
   	     SELECT @c_errmsg = RTRIM(@c_errmsg) + ' (isp_RCM_MB_VFCDC_PKCFM)' 
   	     GOTO ENDPROC      	
      END
   	
      FETCH NEXT FROM cur_Orders INTO @c_Orderkey, @c_Storerkey
   END
   CLOSE cur_Orders  
   DEALLOCATE cur_Orders                                   
       
ENDPROC:   

  IF (SELECT CURSOR_STATUS('LOCAL','cur_Orders')) >=0 
  BEGIN
     CLOSE cur_Orders           
     DEALLOCATE cur_Orders      
  END  
  
  IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL
     DROP TABLE #TMP_ORDERS;
   
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_VFCDC_PKCFM'  
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
END -- End PROC  

GO