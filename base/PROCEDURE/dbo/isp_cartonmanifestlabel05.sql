SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CartonManifestLabel05    								*/
/* Creation Date: 21/09/2010                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#186545                                                  */
/*                                                                      */
/* Called By: r_dw_carton_manifest_Label_05                             */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 26-Nov-2010  NJOW01  1.1   Modify notes1 and susr1                   */
/* 14-Nov-2011  YTWan   1.2   SOS#229394-Size get from Sku.Measurement  */
/*                            (Wan01)                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_CartonManifestLabel05] (
   @c_pickslipno NVARCHAR(10),
   @c_startcartonno NVARCHAR(5),
   @c_endcartonno NVARCHAR(5))
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @Result TABLE(
            loadkey NVARCHAR(10) NULL,
            externorderkey NVARCHAR(30) NULL,
            c_company NVARCHAR(45) NULL,
            c_city NVARCHAR(45) NULL,
            consigneekey NVARCHAR(15) NULL,
            c_address1 NVARCHAR(45) NULL,
            c_address2 NVARCHAR(45) NULL,
            c_address3 NVARCHAR(45) NULL,
            c_address4 NVARCHAR(45) NULL,
            c_contact1 NVARCHAR(30) NULL,
            c_phone1 NVARCHAR(18) NULL,
            notes1 NVARCHAR(254) NULL,
            size NVARCHAR(5) NULL,
            cartonno int NULL,
            qty int NULL,
            susr1 NVARCHAR(18) NULL,
            linetype NVARCHAR(1) NULL)
            
    SELECT O.Loadkey, 
           MAX(O.ExternOrderkey) AS ExternOrderkey, 
           MAX(O.c_company) AS c_company,
           MAX(O.c_city) AS c_city, 
           MAX(O.Consigneekey) AS consigneekey, 
           ISNULL(MAX(O.c_address1),'') AS c_address1, 
           ISNULL(MAX(O.c_address2),'') AS c_address2, 
           ISNULL(MAX(O.c_address3),'') AS c_address3,
           ISNULL(MAX(O.c_address4),'') AS c_address4, 
           MAX(O.c_contact1) AS c_contact1, 
           MAX(O.c_phone1) AS c_phone1,
           --MAX(CONVERT(varchar(254),SKU.Notes1)) AS notes1,
           MAX(RTRIM(PD.SKU)+'('+RTRIM(ISNULL(CONVERT(nvarchar(254),SKU.Notes1),''))+')') AS notes1,
           --(Wan01) - START
           --MAX(SKU.Size) AS size,
           MAX(SKU.Measurement) AS size,
           --(Wan01) - END
           PD.Cartonno,
           SUM(PD.Qty) AS Qty,
           ISNULL(MAX(S.Susr1),'') AS Susr1
           --ISNULL(MAX(SKU.Susr1),'') AS Susr1
    INTO #TEMP_LBL 
    FROM PACKHEADER PH (NOLOCK)
    JOIN PACKDETAIL PD (NOLOCK) ON (PH.Pickslipno = PD.Pickslipno)
    JOIN ORDERS O (NOLOCK) ON (O.Loadkey = PH.Loadkey)
    JOIN SKU (NOLOCK) ON (PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
    JOIN STORER S (NOLOCK) ON O.Consigneekey=S.StorerKey    
    WHERE PH.Pickslipno = @c_pickslipno
    AND PD.CartonNo BETWEEN CAST(@c_StartCartonNo AS int) AND CAST(@c_EndCartonNo AS int)
    GROUP BY O.Loadkey, 
           PD.Cartonno
                   
    INSERT INTO @Result (Loadkey, externorderkey, c_company, c_city, consigneekey, c_address1, 
                         c_address2, c_address3, c_address4, c_contact1, c_phone1, notes1, 
                         size, cartonno, qty, susr1, Linetype)
    SELECT #TEMP_LBL.Loadkey, 
           #TEMP_LBL.externorderkey, 
           #TEMP_LBL.c_company, 
           #TEMP_LBL.c_city, 
           #TEMP_LBL.consigneekey, 
           #TEMP_LBL.c_address1, 
           #TEMP_LBL.c_address2, 
           #TEMP_LBL.c_address3, 
           #TEMP_LBL.c_address4, 
           #TEMP_LBL.c_contact1, 
           #TEMP_LBL.c_phone1, 
           #TEMP_LBL.notes1, 
           #TEMP_LBL.size, 
           #TEMP_LBL.cartonno, 
           #TEMP_LBL.qty, 
           --#TEMP_LBL.susr1, 
           '',
           '1' 
    FROM #TEMP_LBL

    /*INSERT INTO @Result (Loadkey, externorderkey, c_company, c_city, consigneekey, c_address1, 
                         c_address2, c_address3, c_address4, c_contact1, c_phone1, notes1, 
                         size, cartonno, qty, susr1, Linetype)
    SELECT #TEMP_LBL.Loadkey, 
           #TEMP_LBL.externorderkey, 
           #TEMP_LBL.c_company, 
           #TEMP_LBL.c_city, 
           #TEMP_LBL.consigneekey, 
           #TEMP_LBL.c_address1, 
           #TEMP_LBL.c_address2, 
           #TEMP_LBL.c_address3, 
           #TEMP_LBL.c_address4, 
           #TEMP_LBL.c_contact1, 
           #TEMP_LBL.c_phone1, 
           #TEMP_LBL.notes1, 
           #TEMP_LBL.size, 
           #TEMP_LBL.cartonno, 
           #TEMP_LBL.qty, 
           #TEMP_LBL.susr1, 
           '2' 
    FROM #TEMP_LBL
    WHERE #TEMP_LBL.susr1 <> ''*/

    INSERT INTO @Result ( cartonno, susr1, Linetype)
    SELECT #TEMP_LBL.cartonno, 
           #TEMP_LBL.susr1, 
           '2' 
    FROM #TEMP_LBL
    WHERE #TEMP_LBL.susr1 <> ''
		        
    SELECT * 
    FROM @Result 
    ORDER BY cartonno, 
             linetype
    
 END        

GO