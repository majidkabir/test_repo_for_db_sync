SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                    
/* Store Procedure: isp_CartonManifestLabel32_Prn                             */                    
/* Creation Date: 18-Dec-2019                                                 */                    
/* Copyright: LFL                                                             */                    
/* Written by: WLChooi                                                        */                    
/*                                                                            */                    
/* Purpose: WMS-11496 - [CN]_Fanatics_ECOMPacking_Print_ZPL_Label_CR          */                     
/*                                                                            */                    
/* Called By:  r_dw_carton_manifest_label_31_prn                              */                    
/*                                                                            */                    
/* PVCS Version: 1.0                                                          */                    
/*                                                                            */                    
/* Version: 1.1                                                               */                    
/*                                                                            */                    
/* Data Modifications:                                                        */                    
/*                                                                            */                    
/* Updates:                                                                   */                    
/* Date         Author    Ver.  Purposes                                      */ 
/* 2021-Apr-09  CSCHONG   1.1   WMS-16024 PB-Standardize TrackingNo (CS01)    */
/******************************************************************************/        
      
CREATE PROC [dbo].[isp_CartonManifestLabel32_Prn]      
       @c_Pickslipno      NVARCHAR(50) = '', --Storerkey/Orderkey/TrackingNo    
       @c_StartCartonNo   NVARCHAR(10) = '',
       @c_EndCartonNo     NVARCHAR(10) = ''    
AS       
       
BEGIN                  
   SET NOCOUNT ON                  
   SET ANSI_WARNINGS OFF                  
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF       
   
   DECLARE @n_StartTCnt            INT
          ,@n_Continue             INT = 1
          ,@b_Success              INT = 0
          ,@n_Err                  INT = 0 
          ,@c_ErrMsg               NVARCHAR(255) = ''
          ,@c_Orderkey             NVARCHAR(10)  = ''
          ,@c_PrintFromViewReport  NVARCHAR(1)   = 'N'
          ,@c_PrintData            NVARCHAR(MAX) = ''
          ,@c_PrintData1           NVARCHAR(4000) = ''
          ,@c_PrintData2           NVARCHAR(4000) = ''
          ,@c_PrintData3           NVARCHAR(4000) = ''

   DECLARE @d_Trace_StartTime      DATETIME      
          ,@d_Trace_EndTime        DATETIME
          ,@c_UserName             NVARCHAR(20) 
                                   
   SET @d_Trace_StartTime = GETDATE()   
   SET @n_StartTCnt       = @@TRANCOUNT
   SET @c_UserName        = SUSER_SNAME()

   IF @c_StartCartonNo = NULL SET @c_StartCartonNo = ''
   IF @c_EndCartonNo   = NULL SET @c_EndCartonNo   = ''
      
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ORDERKEY = @c_Pickslipno)
   BEGIN
      SET @c_Orderkey = @c_Pickslipno

      SET @c_PrintFromViewReport = 'Y'
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE UserDefine04 = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey = Orderkey
      FROM ORDERS (NOLOCK)
      WHERE UserDefine04 = @c_Pickslipno

      SET @c_PrintFromViewReport = 'Y'
   END

   SELECT @c_PrintData = ISNULL(CT.PrintData,'')
   FROM PACKHEADER PH (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   JOIN CartonTrack CT (NOLOCK) ON CT.LabelNo = OH.Orderkey AND CT.TrackingNo = OH.TrackingNo --OH.UserDefine04   --CS01
   JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'FedexITF' 
                            AND CL.Code = OH.Shipperkey 
                            AND CL.Short = '1'
   WHERE PH.Pickslipno = CASE WHEN @c_PrintFromViewReport = 'Y' THEN PH.Pickslipno ELSE @c_Pickslipno END
     AND PD.CartonNo BETWEEN CASE WHEN @c_PrintFromViewReport = 'Y' THEN 1 ELSE CAST(@c_StartCartonNo AS INT) END
                         AND CASE WHEN @c_PrintFromViewReport = 'Y' THEN 9999 ELSE CAST(@c_EndCartonNo AS INT) END
     AND OH.Orderkey   = CASE WHEN @c_PrintFromViewReport = 'Y' THEN @c_Orderkey ELSE OH.Orderkey END
   
   SET @d_Trace_EndTime = GETDATE()   

   --SELECT LEFT(@c_PrintData,4000),SUBSTRING(@c_PrintData,4001,4000),SUBSTRING(@c_PrintData,8000,4000)
   SELECT @c_PrintData1 = LEFT(@c_PrintData,4000)
   SELECT @c_PrintData2 = SUBSTRING(@c_PrintData,4001,4000)
   SELECT @c_PrintData3 = SUBSTRING(@c_PrintData,8000,4000)

   SELECT @c_PrintData1,@c_PrintData2,@c_PrintData3

   --Debug in PB
   --SELECT @c_PrintData1,@c_PrintData2,'1'

   EXEC isp_InsertTraceInfo       
       @c_TraceCode = 'ZPLPrinting',      
       @c_TraceName = 'isp_CartonManifestLabel32_Prn',      
       @c_starttime = @d_Trace_StartTime,      
       @c_endtime   = @d_Trace_EndTime,      
       @c_step1 = @c_UserName,      
       @c_step2 = @c_PrintFromViewReport,      
       @c_step3 = '',      
       @c_step4 = '',      
       @c_step5 = '',      
       @c_col1 = @c_Pickslipno,       
       @c_col2 = @c_StartCartonNo,      
       @c_col3 = @c_EndCartonNo,      
       @c_col4 = @c_Orderkey,      
       @c_col5 = '',      
       @b_Success = 1,      
       @n_Err = 0,      
       @c_ErrMsg = ''   
   
QUIT_SP:

END      

GO