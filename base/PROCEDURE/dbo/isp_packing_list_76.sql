SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_76                                */
/* Creation Date: 22-MAY-2020                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-13403 -[CN] MoleSkine B2B PackingList                    */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_76                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Jun-2020  CSCHONG   1.1   WMS-13403 fix CBM value (CS01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_76] (
  @cMBOLKey NVARCHAR( 10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid int,
           @c_cartontype     NVARCHAR(10),
           @c_prevcartontype NVARCHAR(10),
           @n_cnt int,
           @n_cntbuyerpo int,
           @n_cntExtord  int
             

  DECLARE @c_pickslipno        NVARCHAR (20),
          @c_loadkey           NVARCHAR(20),
          @c_Delimiter         NVARCHAR(1),
          @c_buyerpo           NVARCHAR(20) ,
          @c_grpbuyerpo        NVARCHAR(250), 
          @c_getbuyerpo        NVARCHAR(250),
          @c_ExternOrderkey    NVARCHAR(50),
          @c_grpExternOrderkey NVARCHAR(510),
          @c_getExternOrderkey NVARCHAR(510),
          @n_PIWGT             FLOAT,
          @n_CBM               FLOAT,
          @n_cntlabelno        INT

  SET @c_Delimiter = ','


  CREATE TABLE #PACKLIST76 
         (  C_Company      NVARCHAR(45) NULL
         , C_Address1      NVARCHAR(45) NULL
         , C_Address2      NVARCHAR(45) NULL
         , C_Address3      NVARCHAR(45) NULL
         , C_Address4      NVARCHAR(45) NULL
         , c_Contact1      NVARCHAR(30) NULL 
         , c_Phone1        NVARCHAR(18) NULL
         , ST_Company      NVARCHAR(45) NULL
         , ST_Address1     NVARCHAR(45) NULL
         , ST_Address2     NVARCHAR(45) NULL
         , ST_Address3     NVARCHAR(45) NULL
         , ST_Address4     NVARCHAR(45) NULL
         , ST_Contact1     NVARCHAR(30) NULL 
         , ST_Phone1       NVARCHAR(18) NULL         
         , Loadkey         NVARCHAR(10) NULL        
         , Pickslipno      NVARCHAR(20) NULL        
         , mbolkey         NVARCHAR(10) NULL  
         , BOOKREF         NVARCHAR(30) NULL
         , F_Address1      NVARCHAR(45) NULL
         , F_Address2      NVARCHAR(45) NULL
         , F_Address3      NVARCHAR(45) NULL
         , BuyerPO         NVARCHAR(250) NULL
         , ExternOrdKey    NVARCHAR(550) NULL 
         , PIWGT           FLOAT NULL
         , CBM             FLOAT NULL 
         , STNotes2        NVARCHAR(4000) NULL
         , CntlabelNo      INT NULL 
         )  



   INSERT INTO #PACKLIST76 ( C_Company  
                           , C_Address1 
                           , C_Address2 
                           , C_Address3 
                           , C_Address4
                           , c_Contact1
                           , c_Phone1   
                           , ST_Company   
                           , ST_Address1 
                           , ST_Address2 
                           , ST_Address3
                           , ST_Address4 
                           , ST_Contact1 
                           , ST_Phone1 
                           , Loadkey  
                           , Pickslipno   
                           , mbolkey   
                           , BOOKREF  
                           , F_Address1
                           , F_Address2  
                           , F_Address3
                           , BuyerPO      
                           , ExternOrdKey
                           , PIWGT
                           , CBM 
                           , STNotes2
                           , Cntlabelno )                   

    select  DISTINCT    OH.c_company as c_Company,
               ISNULL(OH.c_address1,'') as C_Add1,
               ISNULL(OH.c_address2,'') as C_Add2,
               ISNULL(OH.c_address3,'') as C_Add3,
               ISNULL(OH.c_address4,'') as C_Add4, 
               ISNULL(OH.c_Contact1,'') as C_Contact1,
               ISNULL(OH.c_phone1,'') as C_Phone1,
               ST.B_company as ST_Company,
               --ISNULL(ST.address1,'') as ST_Add1,
               --ISNULL(ST.address2,'') as ST_Add2,
               --ISNULL(ST.address3,'') as ST_Add3,
               --ISNULL(ST.address4,'') as ST_Add4, 
               '','','','',
               ISNULL(ST.B_Contact1,'') as ST_Contact1,
               ISNULL(ST.B_phone1,'') as ST_Phone1,
               OH.loadkey as Loadkey,
               ph.pickslipno as Pickslipno,
               MB.MBOLKey as mbolkey,
               MB.Bookingreference AS BOOKREF,
               ISNULL(F.Address1,'') as F_Address1,
               ISNULL(F.Address2,'') as F_Address2,
               ISNULL(F.Address3,'') as F_Address3,
               '' , '' ,0,0,
               ISNULL(ST.notes2,'') AS STNotes2,
               0  
   FROM MBOL MB WITH (NOLOCK)                  
          JOIN MBOLDETAIL MBD WITH (NOLOCK) ON (MB.MBOLKey = MBD.MBOLKey)
          JOIN ORDERS OH WITH  (NOLOCK) ON (OH.OrderKey = MBD.OrderKey)
          JOIN FACILITY F WITH (NOLOCK) ON F.Facility = OH.Facility
          JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = OH.consigneekey
          JOIN PACKHEADER PH WITH (NOLOCK) ON ( OH.Loadkey = PH.Loadkey)
   WHERE MB.MBOLKey = @cMBOLKey
   ORDER BY mb.mbolkey desc 

  SET @c_grpbuyerpo = ''
  SET @c_getbuyerpo = '' 
  SET @c_grpExternOrderkey = ''
  SET @c_getExternOrderkey = ''

DECLARE CUR_ExtnOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT pickslipno,loadkey
        FROM #PACKLIST76
        WHERE mbolkey = @cMBOLKey
        ORDER BY pickslipno,loadkey

        OPEN CUR_ExtnOrdKey

        FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_pickslipno,@c_loadkey

        WHILE @@FETCH_STATUS <> -1
        BEGIN
        SET @c_buyerpo = ''
        SET @c_ExternOrderkey = ''
        SET @n_PIWGT = 0
        SET @n_CBM = 0 
        SET @c_cartontype = ''
        SET @c_grpbuyerpo = ''
        SET @c_getbuyerpo = ''
        SET @c_grpExternOrderkey = ''
        SET @c_getExternOrderkey = ''
        SET @n_cntbuyerpo  = 1
        SET @n_cntExtord  = 1
        SET @n_cntlabelno = 0

        SELECT @n_PIWGT = SUM(PI.weight)
             -- ,@c_cartontype = MAX(PI.cartontype)
        FROM PACKINFO PI WITH (NOLOCK)
        WHERE PI.Pickslipno = @c_pickslipno 

       --CS01 START
        SELECT @n_CBM = SUM(CT.cube)
        FROM  packheader PH WITH (NOLOCK)
        JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = PH.Storerkey
        --JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.cartonizationgroup = ST.cartongroup
        JOIN  PACKINFO PI WITH (NOLOCK) ON PI.Pickslipno = PH.Pickslipno
        JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.cartontype = PI.cartontype
        WHERE PH.Pickslipno = @c_pickslipno
        --WHERE CT.CartonType = @c_cartontype 
        --CS01 END 


        SELECT @n_cntlabelno = COUNT(DISTINCT PD.labelno)
        FROM PACKDETAIL PD WITH (NOLOCK)
        WHERE PD.Pickslipno = @c_pickslipno   

        --SELECT @c_buyerpo = OH.buyerpo
        --FROM ORDERS OH WITH (NOLOCK)
        --JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = OH.loadkey 
        -- WHERE PH.PickSlipNo = @c_pickslipno

        --SELECT @c_ExternOrderkey = OH.externorderkey
        --FROM ORDERS OH WITH (NOLOCK)
        --JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = OH.loadkey 
        -- WHERE PH.PickSlipNo = @c_pickslipno


        -- SET @c_grpbuyerpo = @c_buyerpo + @c_Delimiter

         --SET @c_getbuyerpo = @c_getbuyerpo + @c_grpbuyerpo

         --SET @c_grpExternOrderkey = @c_ExternOrderkey + @c_Delimiter
         --SET @c_getExternOrderkey = @c_getExternOrderkey + @c_grpExternOrderkey

        SET @c_getbuyerpo = STUFF((SELECT ',' + RTRIM(OH.buyerpo)  --SELECT @c_buyerpo = OH.buyerpo
        FROM ORDERS OH WITH (NOLOCK)
        JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = OH.loadkey 
        WHERE PH.PickSlipNo = @c_pickslipno
        FOR XML PATH('')),1,1,'' ) 

        SET @c_getExternOrderkey = STUFF((SELECT ',' + RTRIM(OH.externorderkey) -- SELECT @c_ExternOrderkey = OH.externorderkey
        FROM ORDERS OH WITH (NOLOCK)
        JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = OH.loadkey 
         WHERE PH.PickSlipNo = @c_pickslipno
         FOR XML PATH('')),1,1,'' ) 


         UPDATE #PACKLIST76
         SET BuyerPO =  @c_getbuyerpo
            ,ExternOrdKey = @c_getExternOrderkey
            ,PIWGT = @n_PIWGT
            ,CBM = @n_CBM
            ,cntlabelno = @n_cntlabelno
         WHERE Pickslipno =  @c_pickslipno

        FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_pickslipno,@c_loadkey

        END

        CLOSE CUR_ExtnOrdKey
        DEALLOCATE CUR_ExtnOrdKey


   SELECT DISTINCT P76.c_Company AS con_company,
          P76.c_Address1 AS con_address1,
          P76.c_contact1 AS Con_contact,
          P76.c_Address2 AS con_address2,
          P76.c_phone1 AS Con_Phone1,
          P76.ExternOrdKey AS ExtOrdKey,
          P76.c_Address3 AS con_address3,
          P76.Mbolkey AS Mbolkey,
          P76.c_Address4 AS con_address4,                   
          P76.ST_Company AS ST_Company,
          P76.ST_Address1 AS ST_address1,
          P76.ST_Address2 AS ST_address2,
          P76.ST_Address3 AS ST_address3,         
          P76.BuyerPO As BuyerPO, 
          PD.qty   AS PQTY,
          P76.BOOKREF as BookRef,
          P76.ST_Address4 AS ST_address4,
          P76.ST_contact1 AS ST_contact,
          P76.ST_phone1 AS ST_Phone1,
          P76.F_Address1 as F_Address1,
          P76.F_Address2 as F_Address2,
          P76.F_Address3 as F_Address3, 
          PD.LabelNo as Labelno, 
          S.SKU AS sku,
          ISNULL(S.Altsku,'') AS [altsku],   
          S.descr AS [descr],
          P76.PIWGT AS PIWGT,
          P76.CBM AS CBM,
          P76.Loadkey as Loadkey,
          P76.STnotes2 as STnotes2,
          P76.Cntlabelno as CntLabelNo           
          FROM #PACKLIST76 P76 WITH (NOLOCK)                  
          JOIN PACKDETAIL PD WITH (NOLOCK) ON P76.PickSlipNo = PD.PickSlipNo
          JOIN SKU S WITH (NOLOCK) ON (PD.StorerKey = S.StorerKey AND PD.Sku = S.Sku)
   WHERE P76.MBOLKey = @cMBOLKey
   ORDER BY P76.mbolkey,P76.Loadkey,Pd.LabelNo,S.sku

END

GO