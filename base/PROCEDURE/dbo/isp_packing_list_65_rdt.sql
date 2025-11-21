SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_65_rdt                                   */              
/* Creation Date: 17-Apr-2019                                                 */              
/* Copyright: IDS                                                             */              
/* Written by:                                                                */              
/*                                                                            */              
/* Purpose: WMS-8676 - [KR] JUUL_KOREA_Packing_List_Data_Window_NEW           */
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_65_rdt                                       */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/* 30/08/2019   WLChooi   1.1   WMS-10398 - Add new colum (WL01)              */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_65_rdt]             
       (@c_Pickslipno     NVARCHAR(10) = '',
        @c_StartCartonNo  NVARCHAR(10) = '0',
        @c_EndCartonNo    NVARCHAR(10) = '0')              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_Continue        INT = 1,
           @c_Storerkey       NVARCHAR(20)
   
   IF @c_StartCartonNo = NULL SET @c_StartCartonNo = 1
   IF @c_EndCartonNo   = NULL SET @c_EndCartonNo   = 9999

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM Packheader (NOLOCK) 
      WHERE Pickslipno = @c_Pickslipno

      SELECT @c_Pickslipno AS Pickslipno
             ,ISNULL(CL.CODE,'') AS CODE
             ,ISNULL(CL.LONG,'') AS LONG
      INTO #ReportConstant
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'RPTCONST' AND CL.STORERKEY = @c_Storerkey
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN      
      SELECT ISNULL(OH.C_Company,'') AS C_Company            
           , ISNULL(OH.C_Address1,'') AS C_Address1
           , ISNULL(OH.C_Address2,'') AS C_Address2
           , ISNULL(OH.C_City,'') AS C_City
           , ISNULL(OH.C_Zip,'') AS C_Zip
           , ISNULL(OH.C_Address4,'') AS C_Address4
           , ISNULL(OH.C_Phone1,'') AS C_Phone1
           , ISNULL(OH.B_Company,'') AS B_Company
           , ISNULL(OH.B_Address1,'') AS B_Address1
           , ISNULL(OH.B_Address2,'') AS B_Address2
           , ISNULL(OH.B_City,'') AS B_City
           , ISNULL(OH.B_Zip,'') AS B_Zip
           , ISNULL(OH.B_Address4,'') AS B_Address4
           , ISNULL(OH.B_Phone1,'') AS B_Phone1
           , ISNULL(PD.SKU,'') AS SKU
           , ISNULL(S.DESCR,'') AS DESCR
           , ISNULL(PD.QTY,0) AS Qty 
           , PD.CartonNo AS CartonNo --CASE WHEN ISNULL(P.CASECNT,0) > 0 THEN CEILING(PD.QTY / P.CASECNT) ELSE 0 END AS QtyPerCasecnt
           , CASE WHEN ISNULL(P.INNERPACK,0) > 0 THEN CEILING(PD.QTY / P.INNERPACK) ELSE 0 END AS QtyPerInnerPack
           , S.GROSSWGT * PD.QTY AS TotalWgt
           --WL01 Start - Add ISNULL() Checking
           , C01 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C01'),'')
           , C02 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C02'),'')
           , C03 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C03'),'')
           , C04 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C04'),'')
           , C05 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C05'),'')
           , C06 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C06'),'')
           , C07 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C07'),'')
           , C08 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C08'),'')
           , C09 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C09'),'')
           , C10 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C10'),'')
           , C11 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C11'),'')
           , C12 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C12'),'')
           , C13 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C13'),'')
           , C14 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C14'),'')
           , C15 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C15'),'')
           , C16 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C16'),'')
           , C17 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C17'),'')
           , C18 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C18'),'')
           , C19 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C19'),'')
           , C20 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C20'),'')
           , C21 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C21'),'')
           , C22 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C22'),'')
           , C23 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C23'),'')
           , C24 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C24'),'')
           , C25 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C25'),'')
           , C26 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C26'),'')
           , C27 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C27'),'')
           , C28 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C28'),'')
           , C29 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C29'),'')
           , C30 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C30'),'')
           , C31 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C31'),'')
           , C32 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C32'),'')
           , C33 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C33'),'')
           , C34 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C34'),'')
           , C35 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C35'),'')
           , C36 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C36'),'')
           , C37 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C37'),'')
           , C38 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C38'),'')
           , C39 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C39'),'')
           , C40 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C40'),'')
           --WL01 End - Add ISNULL() Checking
           , RPTLogo = ISNULL(CL1.NOTES,'')
           , ISNULL(OH.ExternOrderkey,'') AS ExternOrderkey
           , ISNULL(OH.BuyerPO,'') AS BuyerPO
           , GETDATE() AS TodayDate
           , A28 = (SELECT ISNULL(CODELKUP.LONG,'') FROM CODELKUP (NOLOCK) WHERE CODELKUP.LISTNAME = 'RPTCONST' AND CODELKUP.CODE = OH.SHIPPERKEY)
           , TrackingNo = CONVERT(NVARCHAR(4000),STUFF((SELECT ', ' + RTRIM(CT.TrackingNo) FROM CartonTrack CT WHERE CT.KeyName = PH.Storerkey AND CT.LabelNo = PH.Orderkey ORDER BY CT.TrackingNo FOR XML PATH('')),1,1,'' ) )
           , C41 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C41'),'')    --WL01 - Add ISNULL() Checking
           , C42 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C42'),'')    --WL01 - Add ISNULL() Checking
           , C43 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C43'),'')    --WL01 - Add ISNULL() Checking
           , C44 = ISNULL((SELECT ISNULL(RC.Long,'') FROM #ReportConstant RC WHERE RC.CODE = 'C44'),'')    --WL01 - Add ISNULL() Checking
    FROM ORDERS OH (NOLOCK)
    JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
    JOIN PACKDETAIL PD (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO
    JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND S.STORERKEY = OH.STORERKEY
    JOIN PACK P (NOLOCK) ON P.PACKKEY = S.PACKKEY
    LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'RPTLOGO' AND CL1.STORERKEY = OH.STORERKEY AND CL1.LONG = 'r_dw_packing_list_65_rdt'
    WHERE PH.PICKSLIPNO = @c_Pickslipno
    AND PD.CARTONNO BETWEEN CASE WHEN CAST(@c_StartCartonNo AS INT) = 0 THEN 1 ELSE CAST(@c_StartCartonNo AS INT) END AND
                            CASE WHEN CAST(@c_EndCartonNo AS INT)   = 0 THEN 9999 ELSE CAST(@c_EndCartonNo AS INT) END
   END

   IF OBJECT_ID('tempdb..#ReportConstant') IS NOT NULL
      DROP TABLE #ReportConstant
               
END

GO