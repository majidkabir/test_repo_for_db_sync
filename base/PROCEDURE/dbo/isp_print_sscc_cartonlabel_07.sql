SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_Print_SSCC_CartonLabel_07                       */  
/* Creation Date: 21-Mar-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  SG MHAP Print SSCC Label (SOS366109)                       */  
/*                                                                      */  
/* Input Parameters: @@c_ID - Pickdetail.ID                             */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Usage: Call by dw = r_dw_sscc_cartonlabel_07                         */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 19-May-2016  CSCHONG   1.0   Change mapping (CS01)                   */  
/* 02-Aug-2016  CSCHONG   1.1   total Cnt by palletid (CS02)            */  
/* 06-Aug-2021  MINGLE    1.2   WMS-17603 enlarge c_company length and  */  
/*                              change no of line = 5(ML01)             */  
/* 30-Mar-2022  MINGLE    1.3   WMS-19332 add logic to show lot02(ML02) */ 
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel_07] (   
   @c_ID             NVARCHAR( 30)  
  ,@c_ExternOrderkey NVARCHAR(20) = ''  
  ,@c_DWCategory     NVARCHAR(1) = 'H'  
  ,@n_RecGroup       INT         = 0  
   )  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
   DECLARE  
      @b_debug                int  
  
   DECLARE   
      @c_ShipTo_StorerKey        NVARCHAR( 15),  
      @c_ShipTo_Comapnay         NVARCHAR( 45),  
      @c_ShipTo_Addr1            NVARCHAR( 45),  
      @c_ShipTo_Addr2            NVARCHAR( 45),  
      @c_ShipTo_Addr3            NVARCHAR( 45),  
      @c_ShipTo_Zip              NVARCHAR( 18),  
      @n_CntSKU                  int,  
      @c_SKU                     NVARCHAR( 20),  
      @c_Storerkey               NVARCHAR(15),  
      @c_PID                     NVARCHAR(20),  
     -- @c_externOrderkey          NVARCHAR(20),  
      @c_SKUDESCR                NVARCHAR(150),  
      @n_CntCaseid               INT,  
      @n_grosswgt                Float,  
      @n_Pqty                    INT,  
      @n_TTLGrossWgt             INT ,  
      @n_Casecnt                 float,  
      @c_lottable01              NVARCHAR(18),  
      @n_Caseqty                 INT,  
      @n_NoOfLine                INT,             --CS01  
      @n_TTLCnt                  INT,  
      @n_MaxGrp                  INT,  
   @c_lottable02              NVARCHAR(18) --ML02  
        
        
      --SET @n_NoOfLine = 5               --CS01  
      SET @n_NoOfLine = 5               --ML01  
      SET @n_TTLCnt = 0  
      SET @n_MaxGrp = 1  
  
  
   IF @c_DWCategory = 'D'  
   BEGIN  
      GOTO Detail  
   END  
     
     
   -- Declare temp table  
    DECLARE @Temp_SSCCTBLGRP TABLE  
            (  SeqNo          INT IDENTITY (1,1)  
            ,  PLTDUdef01     NVARCHAR(30)  
            ,  SKU            NVARCHAR(20)  
            ,  Lottable01     NVARCHAR( 18) NULL  
            ,  RecGrp         INT  
            ,  casecnt        INT         --(CS02)  
   ,  Lottable02     NVARCHAR( 18) NULL --ML02  
            )  
     
   DECLARE @Temp_SSCCTBLH TABLE (  
         ShipTo_StorerKey        NVARCHAR( 15) NULL,  
         ShipTo_Company          NVARCHAR( 100) NULL, --ML01  
         ShipTo_Addr1            NVARCHAR( 45) NULL,  
         ShipTo_Addr2            NVARCHAR( 45) NULL,  
         ShipTo_Addr3            NVARCHAR( 45) NULL,  
         ShipTo_Addr4            NVARCHAR( 45) NULL,  
         ShipTo_City             NVARCHAR( 45) NULL,   
         ShipTo_Zip              NVARCHAR( 18) NULL,  
         ShipTo_Country          NVARCHAR( 30) NULL,  
         ExternOrderKey          NVARCHAR( 30) NULL,  
         BuyerPO                 NVARCHAR( 20) NULL,  
         PalletKey               NVARCHAR( 20) NULL,   
         SSCC_Labelno            NVARCHAR( 50) NULL,  
         CntCaseID               INT,  
         GrossWeight             Float,  
         PID                     NVARCHAR( 18),  
         RecGrp                  INT,  
         PLTDUdef01              NVARCHAR(30)                  --(CS01)  
         )  
           
           
         INSERT INTO @Temp_SSCCTBLGRP (PLTDUdef01,sku,lottable01,RecGrp,casecnt,lottable02)   --(CS02) --ML02  
           
         SELECT DISTINCT PLTDET.UserDefine01,PLTDET.Sku,LOTT.Lottable01,  
         (Row_Number() OVER (PARTITION BY PLTDET.UserDefine01 ORDER BY PLTDET.UserDefine01 Asc)-1)/@n_NoOfLine  
         ,sum(PLTDET.qty/nullif(p.CaseCnt,0))                                         --(CS02)  
   ,LOTT.Lottable02 --ML02  
         from PICKDETAIL PD WITH (NOLOCK)  
         JOIN PALLETDETAIL PLTDET WITH (NOLOCK) ON PLTDET.Userdefine02 = PD.Pickdetailkey  
         JOIN PALLET PL WITH (NOLOCK) ON PL.PALLETKEY = PLTDET.PALLETKEY  
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PLTDET.Userdefine04   
         JOIN Lotattribute LOTT WITH (NOLOCK) ON LOTT.LOT = PD.LOT  
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PLTDET.SKU AND S.Storerkey = PLTDET.Storerkey  
         JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey  
         WHERE ISNULL(PLTDET.UserDefine01,'') = @c_ID    
         GROUP BY PLTDET.UserDefine01,PLTDET.Sku,LOTT.Lottable01,LOTT.Lottable02 --ML02  
           
         --CS02 Start  
         SELECT @n_TTLCnt = SUM(casecnt)  
               ,@n_MaxGrp = MAX(RecGrp)  
         FROM @Temp_SSCCTBLGRP  
         WHERE PLTDUdef01 = @c_ID   
         --CS02 End  
           
      WHILE @n_MaxGrp >= 0  
      BEGIN  
         INSERT INTO @Temp_SSCCTBLH  
            (   ShipTo_StorerKey,  
                ShipTo_Company,  
                ShipTo_Addr1,  
                ShipTo_Addr2,  
                ShipTo_Addr3,  
                ShipTo_Addr4,  
                ShipTo_City ,   
                ShipTo_Zip,  
                ShipTo_Country,  
                ExternOrderKey,  
                BuyerPO,  
                PalletKey,  
                SSCC_Labelno,  
                CntCaseID,  
                GrossWeight,  
                PID,  
                RecGrp,  
                PLTDUdef01  )                 --CS01  
         SELECT DISTINCT ORD.Storerkey,ORD.c_company,ORD.C_Address1,ISNULL(ORD.C_Address2,''),ISNULL(ORD.C_Address3,''),ISNULL(ORD.C_Address4,''),  
         ISNULL(ORD.C_City,''),ISNULL(ORD.C_zip,''),ISNULL(c_Country,''),ORD.ExternOrderkey,ORD.BuyerPO,ISNULL(RTRIM(PL.PalletKey),''), ('00' + PL.PalletKey) AS'SSCC_Labelno',  
         --count(PDET.Caseid),ROUND(SUM(S.grosswgt/nullif(p.casecnt,0)),0),PD.ID,0,PDET.UserDefine01                                  --CS01  
         @n_TTLCnt,--sum(PLTDET.qty/nullif(p.CaseCnt,0)),                                           --CS02  
         SUM(S.grosswgt*PLTDET.qty),PD.ID,@n_MaxGrp,PLTDET.UserDefine01                           --CS01  
         FROM PICKDETAIL PD WITH (NOLOCK)  
         JOIN PALLETDETAIL PLTDET WITH (NOLOCK) ON PLTDET.Userdefine02 = PD.Pickdetailkey  
         JOIN PALLET PL WITH (NOLOCK) ON PL.PALLETKEY = PLTDET.PALLETKEY  
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PLTDET.Userdefine04   
       --  JOIN Lotattribute LOTT WITH (NOLOCK) ON LOTT.LOT = PD.LOT  
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.Storerkey = PD.Storerkey  
         JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey   
       --  JOIN @Temp_SSCCTBLGRP TGRP ON TGRP.PLTDUdef01=PLTDET.UserDefine01 AND TGRP.sku=PLTDET.sku  
         WHERE PLTDET.UserDefine01 = @c_ID                                                                                    --CS01  
         GROUP BY ORD.Storerkey,ORD.c_company,ORD.C_Address1,ORD.C_Address2,ORD.C_Address3,ORD.C_Address4,  
         ORD.C_City,ORD.C_zip,c_Country,ORD.ExternOrderkey,ORD.BuyerPO,PL.PalletKey,PD.ID,PLTDET.UserDefine01 --,TGRP.RecGrp  
  
         SET @n_MaxGrp = @n_MaxGrp - 1  
      END  
        
        
  SELECT * FROM @Temp_SSCCTBLH   
  ORDER BY ExternOrderkey,RecGrp  
    
  GOTO QUIT_SP  
  
  DETAIL:  
  
  DECLARE @Temp_SSCCTBLDET TABLE (  
         ExternOrderKey          NVARCHAR( 30) NULL,  
         SKU                     NVARCHAR( 20) NULL,  
         SKUDesc                 NVARCHAR( 150) NULL,  
         Lottable01              NVARCHAR( 18) NULL,  
         CaseQty                 INT,  
         RecGrp                  INT,  
         PID                     NVARCHAR( 18),  
			Lottable02              NVARCHAR( 18) NULL, --ML02  
			Showlot02               NVARCHAR( 5) NULL)  --ML02  
  
  
  INSERT INTO @Temp_SSCCTBLDET  
  (      ExternOrderKey,  
         SKU,  
         SKUDesc,  
         Lottable01,  
         CaseQty,  
         RecGrp,  
         PID,  
			Lottable02,--ML02  
			Showlot02) --ML02  
  
   SELECT ORD.ExternOrderkey,PLTDET.SKU,S.Descr,LOTT.Lottable01,SUM(PLTDET.qty/nullif(p.casecnt,0)),  
   (Row_Number() OVER (PARTITION BY ORD.ExternOrderkey ORDER BY ORD.ExternOrderkey Asc)-1)/@n_NoOfLine,PD.ID,  
   LOTT.Lottable02,ISNULL(CL.SHORT,'') AS Showlot02 --ML02  
   FROM PICKDETAIL PD WITH (NOLOCK)  
   JOIN PALLETDETAIL PLTDET WITH (NOLOCK) ON PLTDET.Userdefine02 = PD.Pickdetailkey  
   JOIN PALLET PL WITH (NOLOCK) ON PL.PALLETKEY = PLTDET.PALLETKEY  
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PLTDET.Userdefine04   
   JOIN Lotattribute LOTT WITH (NOLOCK) ON LOTT.LOT = PD.LOT  
   JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.Storerkey = PD.Storerkey  
   JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey   
   LEFT JOIN CODELKUP CL(NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'Showlot02'   
										   AND CL.Storerkey = S.Storerkey AND CL.Long = 'r_dw_sscc_cartonlabel_07' --ML02  
   WHERE PLTDET.UserDefine01 = @c_ID                                               --CS01  
   AND ORD.ExternOrderkey = @c_externOrderkey  
   GROUP BY ORD.ExternOrderkey,PLTDET.SKU,S.Descr,LOTT.Lottable01,PD.ID,LOTT.Lottable02,ISNULL(CL.SHORT,'') --ML02  
    
  
   SELECT *  
   FROM @Temp_SSCCTBLDET  
   WHERE RecGrp=@n_RecGroup  
  
   GOTO QUIT_SP  
  
   --DROP TABLE @Temp_SSCCTBLH  
     
 --  DROP TABLE @Temp_SSCCTBLDET  
  
     
 QUIT_SP:  
  
     
  
END  

GO