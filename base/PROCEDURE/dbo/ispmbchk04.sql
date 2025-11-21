SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispMBCHK04                                         */  
/* Creation Date: 08-APR-2014                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#306663- FBR MBOL Extended validation SP                 */
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
CREATE PROCEDURE [dbo].[ispMBCHK04]
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

   SET @n_Continue= 1
   SET @n_Err     = 0
   SET @nSuccess  = 1
   SET @c_ErrMsg  = ''

   TRUNCATE TABLE #ErrorLogDetail
   INSERT INTO #ErrorLogDetail (Key1, LineText)
   SELECT DISTINCT M.Orderkey
         ,CONVERT(CHAR(10), ISNULL(M.Orderkey,'')) + ' ' 
         +CONVERT(CHAR(20), ISNULL(PD.DropID,'')) + ' '
   FROM #MBOLCheck M
   JOIN dbo.ORDERS               OH    WITH (NOLOCK) ON (M.Orderkey = OH.Orderkey)        
   LEFT JOIN dbo.PICKDETAIL      PD    WITH (NOLOCK) ON (OH.Orderkey=PD.Orderkey) 
   LEFT JOIN dbo.CONTAINERDETAIL CTNRD WITH (NOLOCK) ON (PD.DropID = CTNRD.PalletKey)
   WHERE CTNRD.ContainerKey IS NULL
   AND NOT EXISTS (SELECT 1 FROM CODELKUP CL WITH (NOLOCK) WHERE CL.ListName = 'MBCEXCSOTY' AND CL.Code = OH.Type 
                   AND CL.Storerkey = OH.Storerkey)

   IF EXISTS (SELECT 1 FROM #ErrorLogDetail)     
   BEGIN  
      SET @nSuccess = 0     
      SET @n_Continue = 4      
      SET @n_err=75001    
      SET @c_errmsg='There is Carton not loaded to container.'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')            
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERRORMSG',
                                                                             'There is Carton not loaded to container.')    
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------') 

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), 'Orderkey')  + ' '
                                 + CONVERT(CHAR(20), 'Carton #')   + ' ' 

                                 )      
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                   CONVERT(CHAR(10), REPLICATE('-', 10)) + ' '  
                                 + CONVERT(CHAR(20), REPLICATE('-', 20)) + ' ' 
                                      )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
      SELECT @cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR', LineText
      FROM #ErrorLogDetail 
   END
                       
   QUIT_SP:
END

GO