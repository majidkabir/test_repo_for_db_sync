SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GetDManifest_02                                */  
/* Creation Date: 02/09/2010                                            */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: SFC name label SOS#188316                                   */  
/*                                                                      */  
/* Called By: r_dw_dmanifest_02                                         */  
/*                                                                      */  
/* PVCS Version: 1.4                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 10-May-2011  NJOW    1.1   214516 - Only show totes were scan to van */   
/* 11-May-2012  YTWan   1.2   SOS#244019 - Change Company Logo.(Wan01)  */   
/* 28-Nov-2012  NJOW02  1.3   262669-Change fields mapping to           */  
/*                            palletdetail                              */  
/* 10-May-2022  WLChooi 1.4   DevOps Combine Script                     */
/* 10-May-2022  WLChooi 1.4   WMS-19628 Extend Userdefine02 column to   */
/*                            40 (WL01)                                 */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetDManifest_02] (@c_mbolkey NVARCHAR(10))  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @c_PlaceOfLoadingQualifier NVARCHAR(10)  
      
    DECLARE @result TABLE(             
            store NVARCHAR(85) NULL,   --WL01  
            labelno NVARCHAR(20) NULL,  
            copydesc NVARCHAR(30) NULL,  
            remark NVARCHAR(100) NULL,  
            editdate datetime NULL,  
            mbolkey NVARCHAR(10) NULL,  
            Storerkey   NVARCHAR(15) NULL,  --(Wan01)  
            ToteCount INT NULL,  --NJOW02
            BoxCount INT NULL) --NJOW02
              
    SELECT @c_PlaceOfLoadingQualifier = PlaceOfLoadingQualifier   
    FROM MBOL(NOLOCK)  
    WHERE Mbolkey = @c_mbolkey  
      
    IF @c_PlaceOfLoadingQualifier = 'NS'   
    BEGIN             
       INSERT INTO @result (store, labelno, copydesc, remark, editdate, mbolkey, Storerkey, totecount, boxcount)     --(Wan01)  
       SELECT DISTINCT RTRIM(ISNULL(PD.Userdefine02,'')) + ' - ' + ISNULL(STORER.Company,''),  
              PD.UserDefine05, --PD.CaseId,  
              'STORE COPY',  
              CONVERT(NVARCHAR(100),MBOL.Remarks),  
              MBOL.Editdate,  
              MBOL.Mbolkey,  
              PD.Storerkey,            --(Wan01)  
              CASE WHEN LEFT(PD.UserDefine05,1) = '9' THEN --NJOW02
                   0
              ELSE 1 END AS ToteCount, 
              CASE WHEN LEFT(PD.UserDefine05,1) = '9' THEN --NJOW02
                   1
              ELSE 0 END AS BoxCount             
       FROM MBOL (NOLOCK)  
       JOIN PALLETDETAIL PD (NOLOCK) ON MBOL.Mbolkey = PD.Userdefine03  
       LEFT JOIN STORER (NOLOCK) ON PD.Userdefine02 = STORER.Storerkey  
       --JOIN RDT.RDTScanToTruck S2T (NOLOCK) ON (MBOL.MBOLkey = S2T.MBOLKey AND PD.CaseId = S2T.Refno) --NJOW  
       WHERE MBOL.Mbolkey = @c_mbolkey   
       AND PD.Userdefine02 <> 'ECOM'  
       ORDER BY 1, PD.UserDefine05 --PD.CaseId    
         
       INSERT INTO @result (store, labelno, copydesc, remark, editdate, mbolkey, Storerkey, totecount, boxcount)     --(Wan01)  
       SELECT DISTINCT RTRIM(ISNULL(PD.Userdefine02,'')) + ' - ' + ISNULL(STORER.Company,''),  
              PD.UserDefine05, --PD.CaseId,  
              'DRIVER COPY',  
              CONVERT(NVARCHAR(100),MBOL.Remarks),  
              MBOL.Editdate,  
              MBOL.Mbolkey,  
              PD.Storerkey,            --(Wan01)  
              CASE WHEN LEFT(PD.UserDefine05,1) = '9' THEN --NJOW02
                   0
              ELSE 1 END AS ToteCount, 
              CASE WHEN LEFT(PD.UserDefine05,1) = '9' THEN --NJOW02
                   1
              ELSE 0 END AS BoxCount             
       FROM MBOL (NOLOCK)  
       JOIN PALLETDETAIL PD (NOLOCK) ON MBOL.Mbolkey = PD.Userdefine03  
       LEFT JOIN STORER (NOLOCK) ON PD.Userdefine02 = STORER.Storerkey  
       --JOIN RDT.RDTScanToTruck S2T (NOLOCK) ON (MBOL.MBOLkey = S2T.MBOLKey AND PD.CaseId = S2T.Refno) --NJOW  
       WHERE MBOL.Mbolkey = @c_mbolkey   
       AND PD.Userdefine02 <> 'ECOM'  
       ORDER BY 1, PD.UserDefine05 --PD.CaseId    
    END  
    ELSE  
    BEGIN    
       INSERT INTO @result (store, labelno, copydesc, remark, editdate, mbolkey, Storerkey, totecount, boxcount)     --(Wan01)  
       SELECT RTRIM(ISNULL(ORDERS.Consigneekey,'')) + ' - ' + ISNULL(ORDERS.C_Company,''),  
              PACKDETAIL.LabelNo,  
              'STORE COPY',  
              CONVERT(nvarchar(100),MBOL.Remarks),  
              MBOL.Editdate,  
              MBOL.Mbolkey,  
              ORDERS.Storerkey,            --(Wan01)  
              CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN  --NJOW02
                   0
              ELSE 1 END AS ToteCount, 
              CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                   1
              ELSE 0 END AS BoxCount                           
       FROM MBOL (NOLOCK)  
       JOIN MBOLDETAIL (NOLOCK)ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey)  
       JOIN ORDERS (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)  
       JOIN PACKHEADER (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)  
       JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
       JOIN RDT.RDTScanToTruck S2T (NOLOCK) ON (MBOL.MBOLkey = S2T.MBOLKey AND PACKDETAIL.Labelno = S2T.Refno) --NJOW  
       WHERE MBOL.Mbolkey = @c_mbolkey   
       GROUP BY ORDERS.Consigneekey, ORDERS.C_Company, PACKDETAIL.LabelNo,   
                CONVERT(nvarchar(100),MBOL.Remarks), MBOL.Editdate, MBOL.Mbolkey,  
                ORDERS.Storerkey,          --(Wan01)     
                CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                     0
                ELSE 1 END, 
                CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                     1
                ELSE 0 END                                           
       ORDER BY ORDERS.Consigneekey, PACKDETAIL.LabelNo     
  
       INSERT INTO @result (store, labelno, copydesc, remark, editdate, mbolkey, Storerkey, totecount, boxcount)     --(Wan01)  
       SELECT RTRIM(ISNULL(ORDERS.Consigneekey,'')) + ' - ' + ISNULL(ORDERS.C_Company,''),  
              PACKDETAIL.LabelNo,  
              'DRIVER COPY',  
              CONVERT(nvarchar(100),MBOL.Remarks),  
              MBOL.Editdate,  
              MBOL.Mbolkey,  
              ORDERS.Storerkey,            --(Wan01)  
              CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN  --NJOW02
                   0
              ELSE 1 END AS ToteCount, 
              CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                   1
              ELSE 0 END AS BoxCount                           
       FROM MBOL (NOLOCK)  
       JOIN MBOLDETAIL (NOLOCK)ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey)  
       JOIN ORDERS (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)  
       JOIN PACKHEADER (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)  
       JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
       JOIN RDT.RDTScanToTruck S2T (NOLOCK) ON (MBOL.MBOLkey = S2T.MBOLKey AND PACKDETAIL.Labelno = S2T.Refno) --NJOW  
       WHERE MBOL.Mbolkey = @c_mbolkey   
       GROUP BY ORDERS.Consigneekey, ORDERS.C_Company, PACKDETAIL.LabelNo,   
                CONVERT(nvarchar(100),MBOL.Remarks), MBOL.Editdate, MBOL.Mbolkey,  
                ORDERS.Storerkey,          --(Wan01)     
                CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                     0
                ELSE 1 END, 
                CASE WHEN LEFT(PACKDETAIL.LabelNo,1) = '9' THEN --NJOW02
                     1
                ELSE 0 END                                           
       ORDER BY ORDERS.Consigneekey, PACKDETAIL.LabelNo     
    END             
          
    SELECT *   
    FROM @result  
    ORDER BY store, copydesc desc, labelno  
END  


SET QUOTED_IDENTIFIER OFF

GO