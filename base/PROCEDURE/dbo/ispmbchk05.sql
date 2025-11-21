SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispMBCHK05                                         */  
/* Creation Date: 19-DEC-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#294825 ANF - MBOL Creation                              */
/*          upon Ship MBOL                                              */  
/*                                                                      */  
/* Called By: isp_ValidateMBOL/isp_MBOL_ExtendedValidation              */
/*            (Storerconfig MBOLExtendedValidation/ListName.Long)       */ 
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispMBCHK05]
      @cMBOLKey   NVARCHAR(10)
   ,  @cStorerkey NVARCHAR(15)  
   ,  @nSuccess   INT             OUTPUT   -- @nSuccess = 0 (Fail), @nSuccess = 1 (Success), @nSuccess = 2 (Warning)
   ,  @n_Err      INT             OUTPUT 
   ,  @c_ErrMsg   NVARCHAR(250)   OUTPUT
AS 
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue  INT
         , @c_Storerkey NVARCHAR(15)

   SET @n_Continue= 1
   SET @n_Err     = 0
   SET @nSuccess  = 1
   SET @c_ErrMsg  = ''

   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM #MBOLCheck M

   TRUNCATE TABLE #ErrorLogDetail

   INSERT INTO #ErrorLogDetail (Key1, LineText)
   SELECT DISTINCT OD.Orderkey
         ,CONVERT(CHAR(10), ISNULL(OD.Orderkey,'')) + ' ' 
         +CONVERT(CHAR(20), ISNULL(OD.UserDefine02,'')) + ' '
         +CONVERT(CHAR(20), ISNULL(PD.CaseID,'')) + ' '
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                       AND(OD.OrderLineNumber = PD.OrderLineNumber)
   WHERE (OD.Storerkey = @c_Storerkey)
   AND   (OD.UserDefine09 = '' OR OD.UserDefine09 IS NULL)
   AND   (OD.UserDefine10 = '' OR OD.UserDefine10 IS NULL)
   AND   EXISTS (SELECT 1
                 FROM #MBOLCheck M
                 JOIN ORDERS      WITH (NOLOCK) ON (M.Orderkey = ORDERS.Orderkey)
                 JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) 
                 JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)
                                                AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
                 WHERE PICKDETAIL.CaseID = PD.CaseID 
                 AND   ORDERS.RDD = 'SplitOrder'
                 AND  (ORDERDETAIL.UserDefine09 <> '' AND ORDERDETAIL.UserDefine09 IS NOT NULL)
                 AND  (ORDERDETAIL.UserDefine10 <> '' AND ORDERDETAIL.UserDefine10 IS NOT NULL)
                 )
   
   IF EXISTS (SELECT 1 FROM #ErrorLogDetail)     
   BEGIN  
      SET @nSuccess = 0     
      SET @n_Continue = 4      
      SET @n_err=75001    
      SET @c_errmsg='There is Parent''s Carton No not populate to Child Order'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')            
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERRORMSG',
                                                                             'There is Parent''s Carton No not populate to Child Order.')    
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------') 

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), 'Orderkey')  + ' '
                                 + CONVERT(CHAR(18), 'Consignee #')   + ' ' 
                                 + CONVERT(CHAR(20), 'Carton #')   + ' ' 

                                 )      
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), REPLICATE('-', 10)) + ' '  
                                 + CONVERT(CHAR(18), REPLICATE('-', 18)) + ' '  
                                 + CONVERT(CHAR(20), REPLICATE('-', 20)) + ' ' 
                                      )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
      SELECT @cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR', LineText
      FROM #ErrorLogDetail 
   END

   --Check Parent not pack confirm
   TRUNCATE TABLE #ErrorLogDetail

   INSERT INTO #ErrorLogDetail (Key1, LineText)
   SELECT DISTINCT OD.Orderkey
         ,CONVERT(CHAR(10), ISNULL(OD.Orderkey,'')) + ' ' 
         +CONVERT(CHAR(10), ISNULL(PD.PickSlipNo,'')) + ' '
         +CONVERT(CHAR(18), ISNULL(OD.UserDefine09,'')) + ' '
   FROM #MBOLCheck  M  
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (M.Orderkey = PD.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey)
                                     AND(PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN PACKHEADER  PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   WHERE PH.Status < '9'

   IF EXISTS (SELECT 1 FROM #ErrorLogDetail)     
   BEGIN  
      SET @nSuccess = 0     
      SET @n_Continue = 4      
      SET @n_err=75001    
      SET @c_errmsg='There is Order not Pack Confrim Yet'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')            
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERRORMSG',
                                                                             'There is Order not Pack Confrim Yet')    
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------') 

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), 'Orderkey')  + ' '
                                 + CONVERT(CHAR(10), 'PickSlip #')   + ' ' 
                                 + CONVERT(CHAR(18), 'Parent Order #')   + ' ' 
                                 )      
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), REPLICATE('-', 10)) + ' '  
                                 + CONVERT(CHAR(10), REPLICATE('-', 10)) + ' ' 
                                 + CONVERT(CHAR(18), REPLICATE('-', 18)) + ' ' 
                                      )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
      SELECT @cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR', LineText
      FROM #ErrorLogDetail 
   END
             
   QUIT_SP:
END

GO