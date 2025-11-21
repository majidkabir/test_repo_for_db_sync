SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispMBCHK02                                         */  
/* Creation Date: 16-JUL-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#248597 - US Additional Mbol Validation                  */  
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
/* 14-AUG-2012  YTWan    1.1  SOS#253369:Bug Fixed - To exclude Fluid   */
/*                            Lane. (Wan01)                             */ 
/* 16-AUG-2012  YTWan    1.2  Fixed. Exclude Phase 1 MBOL. (Wan02)      */
/* 18-AUG-2012  LAU      1.2a Fix 1.2 not consider split order(Lau01)   */
/* 13-Sep-2012  YTWan    1.3  SOS#255779:MBOL Preaudit Check to return  */
/*                            allerrors. (Wan03)                        */
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispMBCHK02]
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

   -- Start (Lau01)
   IF EXISTS (SELECT 1 FROM RDT.RDTSCANTOTRUCK WITH (NOLOCK) WHERE MBOLKEY = @cMBOLKey)  
   BEGIN
      GOTO QUIT_SP    
   END
   -- End  (Lau01)   

   --(Wan03) IF @n_continue = 1 OR @n_continue = 2      
   BEGIN 
      TRUNCATE TABLE #ErrorLogDetail
      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT M.Orderkey
            ,CONVERT(CHAR(10), M.Orderkey) + ' ' 
            +CONVERT(CHAR(10), PD.PickSlipNo) + ' '
            +CONVERT(CHAR(20), PD.LabelNo) + ' '
            +CONVERT(CHAR(10), DI.DropID) + ' '
            +CONVERT(CHAR(10), ISNULL(RTRIM(DI.Status),' '))
      FROM #MBOLCheck M
      JOIN dbo.PACKDETAIL   PD  WITH (NOLOCK) ON (M.PickSlipNo=PD.PickSlipNo) 
      LEFT JOIN dbo.DROPIDDETAIL DID WITH (NOLOCK) ON (PD.LabelNo = DID.ChildID) 
      LEFT JOIN dbo.DROPID       DI  WITH (NOLOCK) ON (DID.DropID = DI.DropID) 
      WHERE 
      --Remark to follow script in live db - (START)
      --NOT EXISTS (SELECT 1 FROM WCS_Sortation ST  WITH (NOLOCK) WHERE ST.LabelNo = PD.LabelNo)  --(Wan01)  
      --  AND 
      --Remark to follow script in live db - (END)
      (RTRIM(DI.Status) <> '9' OR DI.Status IS NULL) 
      --(Wan02) - Start 
        AND EXISTS (SELECT 1 FROM TRANSMITLOG3 TL3 WITH (NOLOCK) 
                    JOIN ORDERS OH WITH (NOLOCK) ON (TL3.TableName = 'WAVERESLOG')
                                                 AND(TL3.Key1 = OH.UserDefine09)
                    WHERE OH.Orderkey = M.Orderkey)                              
      --(Wan02) - END
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)     
      BEGIN  
         SET @nSuccess = 0     
         SET @n_Continue = 4      
         SET @n_err=75001    
         SET @c_errmsg='There is Pallet not scanned to Door.'

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')            
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERRORMSG',
                                                                                'There is Pallet not scanned to Door.')    
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------') 

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                      CONVERT(CHAR(10), 'Orderkey')  + ' '
                                    + CONVERT(CHAR(10), 'Pickslip#')   + ' ' 
                                    + CONVERT(CHAR(20), 'Label#')   + ' ' 
                                    + CONVERT(CHAR(10), 'Pallet#') + ' ' 
                                    + CONVERT(CHAR(10), 'Status') + ' '  

                                    )      
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR',  
                                      CONVERT(CHAR(10), REPLICATE('-', 10)) + ' '  
                                    + CONVERT(CHAR(10), REPLICATE('-', 10)) + ' ' 
                                    + CONVERT(CHAR(20), REPLICATE('-', 20)) + ' ' 
                                    + CONVERT(CHAR(10), REPLICATE('-', 10)) + ' ' 
                                    + CONVERT(CHAR(10), REPLICATE('-', 10)) + ' ' 
                                         )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @cMBOLKey, CONVERT(CHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail 
      END  
   END 
                       
   QUIT_SP:
END

GO