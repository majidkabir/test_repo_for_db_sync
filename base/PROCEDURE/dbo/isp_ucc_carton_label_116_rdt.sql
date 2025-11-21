SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_UCC_Carton_Label_116_rdt                       */  
/* Creation Date:08-AUG-2022                                            */  
/* Copyright: LFL                                                       */  
/* Written by: CHONGCS                                                  */  
/*                                                                      */  
/* Purpose: WMS-20427 [CN] Yonex_B2B_CartonLabel                        */  
/*                                                                      */  
/* Called By: r_dw_ucc_carton_label_116_rdt                             */  
/*                                                                      */  
/* Parameters: (Input)  @c_Storerkey      = Storerkey                   */  
/*                      @c_Pickslipno     = Pickslipno                  */  
/*                      @c_StartCartonNo  = CartonNoStart               */  
/*                      @c_EndCartonNo    = CartonNoEnd                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver. Purposes                                 */  
/* 2022-08-08   CHONGCS   1.1  Devops Scripts Combine                   */  
/* 2022-09-01   CHONGCS   1.2  WMS-20427 revised field logic (CS01)     */  
/* 2022-11-01   MINGLE    1.3  WMS-21101 modify logic (ML01)            */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_UCC_Carton_Label_116_rdt]  
                 @c_Storerkey       NVARCHAR(15)  
               , @c_Pickslipno      NVARCHAR(10)  
               , @c_StartCartonNo   NVARCHAR(10)  
               , @c_EndCartonNo     NVARCHAR(10)  
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue  INT  =  1  
          ,@n_maxctn    NVARCHAR(20)  
          ,@c_Getpickslipno    NVARCHAR(20)        --CS01  
          ,@c_sku              NVARCHAR(20)        --CS01  
          ,@c_ctnno            NVARCHAR(20)        --CS01  
          ,@c_getupc           NVARCHAR(50) =''    --CS01  
          ,@c_upc              NVARCHAR(50) =''    --CS01  
          ,@c_updatelastctn    NVARCHAR(1)  ='N'   --CS01  
          ,@c_GetOrdkey        NVARCHAR(20) = ''   --CS01  
          ,@c_PickStatus       NVARCHAR(10) ='0'   --CS01  
          ,@c_Lottable02   NVARCHAR(20)     --ML01   
  
   WHILE @@TRANCOUNT > 1  
   BEGIN  
      COMMIT TRAN  
   END  
  
    CREATE TABLE #TMPUCCCTNLBL116RDT (  
                                        ExternOrderkey     NVARCHAR(50),  
                                        Orderkey           NVARCHAR(20),  
                                        C_contact1         NVARCHAR(50),  
                                        C_Address3         NVARCHAR(45),  
                                        C_Address4         NVARCHAR(45),  
                                        R1                 NVARCHAR(50),  
                                        C_Address1         NVARCHAR(45),  
                                        C_Address2         NVARCHAR(45),  
                                        R2                 NVARCHAR(200),  
                                        sku                NVARCHAR(20),  
                                        PQTY               INT,  
                                        C_Phone1           NVARCHAR(45),  
                                        UPC                NVARCHAR(50),  
                                        CartonNo           NVARCHAR(10),  
                                        logo               NVARCHAR(10),  
                                        c_city             NVARCHAR(10),  
                                        Pickslipno         NVARCHAR(20),  
                                        shipdesc           NVARCHAR(30),  
                                        shipremarks        NVARCHAR(4000)  
                                           
  
                                     )  
  
   IF (@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN  
   
       SELECT @c_GetOrdkey = PH.Orderkey  
       FROM PACKHEADER PH (NOLOCK)  
       WHERE  PH.Pickslipno = @c_Pickslipno  
  
       SELECT @n_maxctn = CAST(MAX(PD.CartonNo) AS NVARCHAR(10))  
       FROM ORDERS ORD (NOLOCK)  
       JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey  
       JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
       WHERE PD.Pickslipno = @c_Pickslipno  
       AND PH.Status = '9' --ML01 To get max cartonno when pack confirm  
       
  
      SELECT TOP 1 @c_PickStatus = PID.status  
      FROM PICKDETAIL PID (NOLOCK)   
       WHERE PID.OrderKey = @c_GetOrdkey  
  
      SELECT TOP 1 @c_Lottable02 = ISNULL(LOTATTRIBUTE.Lottable02,'')  
		FROM LOTATTRIBUTE(NOLOCK)   
		JOIN PICKDETAIL(NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot  
		WHERE PICKDETAIL.OrderKey = @c_GetOrdkey --ML01  
    
  
   INSERT INTO #TMPUCCCTNLBL116RDT  
   (  
       ExternOrderkey,  
       Orderkey,  
       C_contact1,  
       C_Address3,  
       C_Address4,  
       R1,  
       C_Address1,  
       C_Address2,  
       R2,  
       sku,  
       PQTY,  
       C_Phone1,  
       UPC,  
       CartonNo,  
       logo,  
       c_city,  
       Pickslipno,  
       shipdesc,shipremarks  
   )  
      SELECT  ORD.ExternOrderkey  
            , ORD.Orderkey  
            , ORD.C_Company  
            , ISNULL(ORD.C_Address3,'') AS C_Address3  
            , ISNULL(ORD.C_Address4,'') AS C_Address4  
            , ''  AS R1  
            , ISNULL(ORD.C_Address1,'') AS C_Address1  
            , ISNULL(ORD.C_Address2,'') AS C_Address2  
            , ISNULL(ORD.Notes2,'')  AS R2  
            , PD.sku  
            , SUM(PD.qty) AS PQTY  
            , ORD.C_Phone1  
           --, CASE WHEN ISNULL(UCC.UCCno,'') <> '' THEN ISNULL(UCC.UCCno,'')  ELSE ISNULL(PD.UPC,'') END  
			   , CASE WHEN @c_Lottable02 <> '' THEN @c_Lottable02  ELSE ISNULL(PD.UPC,'') END --ML01  
           -- , CASE WHEN @n_maxctn = PD.CartonNo THEN N'尾箱' ELSE CAST(PD.CartonNo AS NVARCHAR(10)) END AS Cartonno  
            , CAST(PD.CartonNo AS NVARCHAR(10)) AS Cartonno  
            , 'YONEX' AS Logo  
            , ISNULL(ORD.C_City,'') AS c_City--N'天津' AS c_city  
            ,PD.Pickslipno  
            ,ISNULL(C2.long,'') AS shipdesc  
            , ISNULL(C.Notes,'') AS shipremarks  
      FROM ORDERS ORD (NOLOCK)  
      JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno   
      --LEFT JOIN PICKDETAIL PID (NOLOCK) ON PID.CaseID = PD.LabelNo    
      -- LEFT JOIN lotxlocxid lli (NOLOCK) ON lli.Lot=PID.Lot AND lli.sku=PID.Sku AND lli.StorerKey = PID.Storerkey  
      --LEFT JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.lot = PID.Lot   
      LEFT JOIN UCC UCC (NOLOCK) ON UCC.uccno = PD.UPC  
  --CROSS APPLY (SELECT TOP 1 UPC.UPC AS UPC FROM UPC WITH (NOLOCK)   
  --             WHERE  UPC.StorerKey=PD.StorerKey AND UPC.Sku=pd.sku AND upc.uom='EA') AS UPC     
      JOIN CODELKUP C (NOLOCK) ON c.LISTNAME='YXRemark' AND C.Storerkey = ORD.StorerKey  
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME='ORDRPRIOR' AND C2.Storerkey = ORD.StorerKey  
                                             AND C2.code=ORD.Priority  
      WHERE PD.Pickslipno = @c_Pickslipno  
      AND PD.CartonNo BETWEEN CAST( @c_StartCartonNo AS INT) AND CAST( @c_EndCartonNo AS INT)  
      AND PH.Storerkey = @c_Storerkey  
      GROUP BY ORD.ExternOrderkey  
            , ORD.Orderkey  
            , ORD.C_Company  
            ,ISNULL(ORD.C_Address1,'')   
            ,ISNULL(ORD.C_Address2,'')   
            ,ISNULL(ORD.C_Address3,'')   
            ,ISNULL(ORD.C_Address4,'')   
         --   , ISNULL(C.long,'')   
            , ISNULL(ORD.Notes2,'')  
            , ORD.C_Phone1   
            --,CASE WHEN ISNULL(UCC.UCCno,'') <> '' THEN ISNULL(UCC.UCCno,'')  ELSE ISNULL(PD.UPC,'')  END  
            ,PD.sku  
            ,PD.CartonNo  
            ,PD.Pickslipno   
            , ISNULL(ORD.C_City,''),ISNULL(C2.long,'') ,ISNULL(C.Notes,'')   
    ,PD.UPC  
      ORDER BY PD.CartonNo  
  
     --CS01 S  
  
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        
                       
         SELECT DISTINCT Pickslipno,sku,CartonNo,upc     
         FROM #TMPUCCCTNLBL116RDT            
         WHERE Pickslipno = @c_Pickslipno         
        -- AND UPC = ''   
         ORDER BY Pickslipno,CartonNo,sku       
              
         OPEN CUR_RowNoLoop                      
                 
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_Getpickslipno,@c_sku,@c_ctnno,@c_upc  
                   
         WHILE @@FETCH_STATUS <> -1                 
         BEGIN     
                SET @c_getupc = ''  
                  
               IF ISNULL(@c_upc,'') = ''  
               BEGIN     
                SELECT @c_getupc = MAX(UPC.UPC)   
                FROM UPC UPC (NOLOCK)  
                WHERE UPC.StorerKey = @c_Storerkey AND UPC.sku = @c_sku AND UPC.UOM ='EA'  
              END   
     
                IF @n_maxctn = CAST(@c_ctnno AS INT)  
                BEGIN  
                     SET @c_updatelastctn = 'Y'  
                END    
  
  
  
             UPDATE #TMPUCCCTNLBL116RDT  
             SET UPC =  CASE WHEN ISNULL(UPC,'') = '' AND @c_getupc <> '' THEN @c_getupc ELSE UPC END  
				 --,CartonNo = CASE WHEN @c_updatelastctn = 'Y' THEN CartonNo + SPACE(3) + N'尾箱' ELSE CartonNo END  
             WHERE Pickslipno = @c_Pickslipno   
             AND UPC = ''  AND sku = @c_sku    
  
				 UPDATE #TMPUCCCTNLBL116RDT  
				 SET CartonNo = CASE WHEN @c_updatelastctn = 'Y' THEN CartonNo + SPACE(3) + N'尾箱' ELSE CartonNo END  
				 WHERE Pickslipno = @c_Pickslipno AND  CartonNo =  @n_maxctn --ML01   
  
       
  
         FETCH NEXT FROM CUR_RowNoLoop INTO  @c_Getpickslipno,@c_sku,@c_ctnno ,@c_upc            
              
         END -- While                       
         CLOSE CUR_RowNoLoop                      
         DEALLOCATE CUR_RowNoLoop  
  
     SELECT * FROM #TMPUCCCTNLBL116RDT  
     ORDER BY Pickslipno,CartonNo  
    --CS01 E  
  
   END  
  
     IF OBJECT_ID('tempdb..#TMPUCCCTNLBL116RDT0') IS NOT NULL  
      DROP TABLE #TMPUCCCTNLBL116RDT  
  
END  

GO