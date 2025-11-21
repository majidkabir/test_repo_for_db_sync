SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: nspConsolidatedPickList01_1                           */  
/* Creation Date:30-Aug-2019                                               */  
/* Copyright: IDS                                                          */  
/* Written by:CSCHONG                                                      */  
/*                                                                         */  
/* Purpose:wms-10248 TH-Diageo Customize Consolidate Pickslip Report       */  
/*                                                                         */  
/* Called By: r_dw_consolidated_pick01_1                                   */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 18-SEP-2019  CSCHONG 1.1   WMS-10248 revised field logic (CS01)         */  
/* 25-SEP-2019  CSCHONG 1.2   WMS-10248 Fix calculate wrong carton (CS02)  */  
/***************************************************************************/  
CREATE PROC [dbo].[nspConsolidatedPickList01_1] (    
 @c_loadkey  NVARCHAR(10)    
 )    
 AS    
 BEGIN       
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET ANSI_NULLS OFF            
    
 DECLARE @d_date_start       datetime,    
      @d_date_end            datetime,    
      @c_sku                 NVARCHAR(20),    
      @c_storerkey           NVARCHAR(15),    
      @c_lot                 NVARCHAR(10),    
      @c_uom                 NVARCHAR(10),    
      @c_Route               NVARCHAR(10),    
      @c_Exe_String          NVARCHAR(60),    
      @n_Qty                 int,    
      @c_Pack                NVARCHAR(10),    
      @n_CaseCnt             int,    
      @c_uom1                NVARCHAR(10),    
      @c_uom3                NVARCHAR(10),  
      @c_NoSortByLogicalLoc  NVARCHAR(1) = 'N'  
    
 DECLARE @c_CurrOrderKey NVARCHAR(10),    
      @c_MBOLKey         NVARCHAR(10),    
      @c_firsttime       NVARCHAR(1),    
      @c_PrintedFlag     NVARCHAR(1),    
      @n_err             int,    
      @n_continue        int,    
      @c_PickHeaderKey   NVARCHAR(10),    
      @b_success         int,    
      @c_errmsg          NVARCHAR(255)  
    
 DECLARE @nStartTranCount int    
  
 DECLARE    @c_ExtenOrderkey     NVARCHAR(50),  
   @c_PreExtenOrderkey  NVARCHAR(50),  
   @c_ExtenOrderkey1    NVARCHAR(50),  
   @c_ExtenOrderkey2    NVARCHAR(50),  
   @c_ExtenOrderkey3    NVARCHAR(50),  
   @c_ExtenOrderkey4    NVARCHAR(50),  
   @c_ExtenOrderkey5    NVARCHAR(50),  
   @c_ExtenOrderkey6    NVARCHAR(50),  
   @c_ExtenOrderkey7    NVARCHAR(50),  
   @c_ExtenOrderkey8    NVARCHAR(50),  
   @n_PACKCASECNT1      INT,            --CS01 START  
            @n_PACKCASECNT2      INT,  
            @n_PACKCASECNT2_FC   INT,  
            @n_PACKCASECNT2_LC   INT,  
   @n_PACKCASECNT3      INT,  
   @n_PACKCASECNT3_FC   INT,  
            @n_PACKCASECNT3_LC   INT,  
   @n_PACKCASECNT4      INT,  
   @n_PACKCASECNT4_FC   INT,  
            @n_PACKCASECNT4_LC   INT,  
   @n_PACKCASECNT6      INT,  
   @n_PACKCASECNT6_FC   INT,  
            @n_PACKCASECNT6_LC   INT,  
   @n_PACKCASECNT12     INT,  
   @n_PACKCASECNT12_FC  INT,  
            @n_PACKCASECNT12_LC  INT,  
   @n_PACKCASECNT24     INT,  
   @n_PACKCASECNT24_FC  INT,  
            @n_PACKCASECNT24_LC  INT,  
   @n_PACKCASECNT48     INT,  
   @n_PACKCASECNT48_FC  INT,  
            @n_PACKCASECNT48_LC  INT,             
   @n_PACKCASECNT       INT,  
   @n_PACKUOMQty        INT,  
   @n_cnt1              INT,  
   @n_recgrp            INT,  
   @n_TTLPACKCNT        INT,  
   @n_FullCtn           INT,  
            @n_LooseCtn          INT           --CS01 END  
  
     
  
 CREATE TABLE #TEMPEXTORDUOM (  
        ExtenOrderkey     NVARCHAR(50) DEFAULT (''),  
     PACKCASECNT1      INT DEFAULT (0),  
     PACKCASECNT2      INT DEFAULT (0),  
     PACKCASECNT2_FC   INT DEFAULT (0),         --CS01 START  
              PACKCASECNT2_LC   INT DEFAULT (0),  
     PACKCASECNT3      INT DEFAULT (0),  
     PACKCASECNT3_FC   INT DEFAULT (0),          
              PACKCASECNT3_LC   INT DEFAULT (0),  
     PACKCASECNT4      INT DEFAULT (0),  
     PACKCASECNT4_FC   INT DEFAULT (0),          
              PACKCASECNT4_LC   INT DEFAULT (0),  
     PACKCASECNT6      INT DEFAULT (0),  
     PACKCASECNT6_FC   INT DEFAULT (0),          
              PACKCASECNT6_LC   INT DEFAULT (0),  
     PACKCASECNT12     INT DEFAULT (0),  
     PACKCASECNT12_FC  INT DEFAULT (0),          
              PACKCASECNT12_LC  INT DEFAULT (0),  
     PACKCASECNT24     INT DEFAULT (0),  
     PACKCASECNT24_FC  INT DEFAULT (0),          
              PACKCASECNT24_LC  INT DEFAULT (0),  
     PACKCASECNT48     INT DEFAULT (0),  
     PACKCASECNT48_FC  INT DEFAULT (0),          
              PACKCASECNT48_LC  INT DEFAULT (0),  
     TTLPACKCNT        INT DEFAULT (0)  
                   )  
  
            SET @c_PreExtenOrderkey = ''  
   SET @c_ExtenOrderkey1 = ''  
   SET @c_ExtenOrderkey2 = ''  
   SET @c_ExtenOrderkey3 = ''  
   SET @c_ExtenOrderkey4 = ''  
   SET @c_ExtenOrderkey5 = ''  
   SET @c_ExtenOrderkey6 = ''  
   SET @c_ExtenOrderkey7 = ''  
   SET @c_ExtenOrderkey8 = ''  
   SET @n_PACKCASECNT1 = 0               --CS01 START  
            SET @n_PACKCASECNT2 = 0  
            SET @n_PACKCASECNT2_FC = 0       
            SET @n_PACKCASECNT2_LC = 0  
   SET @n_PACKCASECNT3 = 0  
   SET @n_PACKCASECNT3_FC = 0  
            SET @n_PACKCASECNT3_LC = 0  
   SET @n_PACKCASECNT4 = 0  
   SET @n_PACKCASECNT4_FC = 0  
            SET @n_PACKCASECNT4_LC = 0  
   SET @n_PACKCASECNT6 = 0  
   SET @n_PACKCASECNT6_FC = 0  
            SET @n_PACKCASECNT6_LC = 0  
   SET @n_PACKCASECNT12 = 0  
   SET @n_PACKCASECNT12_FC = 0  
            SET @n_PACKCASECNT12_LC = 0  
   SET @n_PACKCASECNT24 = 0  
   SET @n_PACKCASECNT24_FC = 0  
            SET @n_PACKCASECNT24_LC = 0  
   SET @n_PACKCASECNT48 = 0  
   SET @n_PACKCASECNT48_FC = 0  
            SET @n_PACKCASECNT48_LC = 0        --CS01 END  
   SET @n_PACKCASECNT  = 0  
   SET @n_cnt1 = 1  
  
   SELECT o.externorderkey as ExtOrderkey,o.loadkey as loadkey,  
            recgrp = Row_number() OVER (PARTITION BY o.loadkey  ORDER BY o.externorderkey)  
            INTO #TEMPEXTORD  
            FROM PICKDETAIL PD WITH (NOLOCK)  
            JOIN ORDERS O WITH (NOLOCK) on pd.orderkey=o.orderkey  
            WHERE loadkey=@c_loadkey  
            GROUP BY externorderkey,o.loadkey  
            ORDER BY externorderkey  
    
  
  
 DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
SELECT ExtOrderkey,recgrp   
FROM #TEMPEXTORD  
where loadkey  = @c_loadkey  
  
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_PreExtenOrderkey,@n_recgrp  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
  
  
 SET @c_ExtenOrderkey1 = ''  
 SET @c_ExtenOrderkey2 = ''  
 SET @c_ExtenOrderkey3 = ''  
 SET @c_ExtenOrderkey4 = ''  
 SET @c_ExtenOrderkey5 = ''  
 SET @c_ExtenOrderkey6 = ''  
 SET @c_ExtenOrderkey7 = ''  
 SET @c_ExtenOrderkey8 = ''  
 SET @n_PACKCASECNT1 = 0               --CS01 START  
 SET @n_PACKCASECNT2 = 0  
 SET @n_PACKCASECNT2_FC = 0       
 SET @n_PACKCASECNT2_LC = 0  
 SET @n_PACKCASECNT3 = 0  
 SET @n_PACKCASECNT3_FC = 0  
 SET @n_PACKCASECNT3_LC = 0  
 SET @n_PACKCASECNT4 = 0  
 SET @n_PACKCASECNT4_FC = 0  
 SET @n_PACKCASECNT4_LC = 0  
 SET @n_PACKCASECNT6 = 0  
 SET @n_PACKCASECNT6_FC = 0  
 SET @n_PACKCASECNT6_LC = 0  
 SET @n_PACKCASECNT12 = 0  
 SET @n_PACKCASECNT12_FC = 0  
 SET @n_PACKCASECNT12_LC = 0  
 SET @n_PACKCASECNT24 = 0  
 SET @n_PACKCASECNT24_FC = 0  
 SET @n_PACKCASECNT24_LC = 0  
 SET @n_PACKCASECNT48 = 0  
 SET @n_PACKCASECNT48_FC = 0  
 SET @n_PACKCASECNT48_LC = 0        --CS01 END  
 SET @n_TTLPACKCNT = 0  
  
 IF @n_recgrp = 1  
 BEGIN  
   SET @c_ExtenOrderkey1 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 2  
 BEGIN  
   SET @c_ExtenOrderkey2 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 3  
 BEGIN  
   SET @c_ExtenOrderkey3 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 4  
 BEGIN  
   SET @c_ExtenOrderkey4 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 5  
 BEGIN  
   SET @c_ExtenOrderkey5 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 6  
 BEGIN  
   SET @c_ExtenOrderkey6 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 7  
 BEGIN  
   SET @c_ExtenOrderkey7 = @c_PreExtenOrderkey  
 END  
 ELSE IF @n_recgrp = 8  
 BEGIN  
   SET @c_ExtenOrderkey8 = @c_PreExtenOrderkey  
 END  
  
 DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT externorderkey,casecnt,SUM(PD.Qty)/CAST(casecnt as int)  as tot,  
   floor(sum(pd.qty)/casecnt) as Fullctn,   
   CASE  
    WHEN sum(pd.qty) - floor(sum(pd.qty)/casecnt)*casecnt  > 0 THEN 1  
         ELSE 0  
   END as loosecnt   
   FROM PICKDETAIL PD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) on pd.orderkey=o.orderkey  
   JOIN sku s WITH (NOLOCK) on pd.sku=s.sku and PD.storerkey = s.storerkey   --(CS02)  
   Join pack pk WITH (NOLOCK) on s.packkey=pk.packkey  
   WHERE  loadkey= @c_loadkey  
   and externorderkey = @c_PreExtenOrderkey  
   and casecnt>0  
   group by externorderkey,casecnt  
   order by externorderkey,casecnt   
    
   OPEN CUR_LOOP     
       
   FETCH NEXT FROM CUR_LOOP INTO @c_ExtenOrderkey  ,@n_PACKCASECNT, @n_PACKUOMQty ,@n_FullCtn,@n_looseCtn   --CS01  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
      --CS01 START    
      IF @n_PACKCASECNT = 1  
   BEGIN  
      SET @n_PACKCASECNT1 = @n_PACKUOMQty  
   END   
   ELSE IF @n_PACKCASECNT = 2  
   BEGIN  
      SET @n_PACKCASECNT2 = @n_PACKUOMQty  
   SET @n_PACKCASECNT2_FC = @n_FullCtn  
   SET @n_PACKCASECNT2_LC = @n_looseCtn  
   END   
   ELSE IF @n_PACKCASECNT = 3  
   BEGIN  
      SET @n_PACKCASECNT3 = @n_PACKUOMQty  
   SET @n_PACKCASECNT3_FC = @n_FullCtn  
   SET @n_PACKCASECNT3_LC = @n_looseCtn  
   END   
   ELSE IF @n_PACKCASECNT = 4  
   BEGIN  
      SET @n_PACKCASECNT4 = @n_PACKUOMQty  
   SET @n_PACKCASECNT4_FC = @n_FullCtn  
   SET @n_PACKCASECNT4_LC = @n_looseCtn  
   END   
   ELSE IF @n_PACKCASECNT = 6  
   BEGIN  
      SET @n_PACKCASECNT6 = @n_PACKUOMQty  
   SET @n_PACKCASECNT6_FC = @n_FullCtn  
   SET @n_PACKCASECNT6_LC = @n_looseCtn  
   END  
   ELSE IF @n_PACKCASECNT = 12  
   BEGIN  
      SET @n_PACKCASECNT12 = @n_PACKUOMQty  
   SET @n_PACKCASECNT12_FC = @n_FullCtn  
   SET @n_PACKCASECNT12_LC = @n_looseCtn  
   END   
   ELSE IF @n_PACKCASECNT = 24  
   BEGIN  
      SET @n_PACKCASECNT24 = @n_PACKUOMQty  
   SET @n_PACKCASECNT24_FC = @n_FullCtn  
   SET @n_PACKCASECNT24_LC = @n_looseCtn  
   END   
   ELSE IF @n_PACKCASECNT = 48  
   BEGIN  
      SET @n_PACKCASECNT48 = @n_PACKUOMQty  
   SET @n_PACKCASECNT48_FC = @n_FullCtn  
   SET @n_PACKCASECNT48_LC = @n_looseCtn  
   END   
  
   FETCH NEXT FROM CUR_LOOP INTO @c_ExtenOrderkey  ,@n_PACKCASECNT, @n_PACKUOMQty ,@n_FullCtn,@n_looseCtn   --CS01  
   END   
   close CUR_LOOP  
   deallocate CUR_LOOP  
  
   --SET @n_TTLPACKCNT =  @n_PACKCASECNT1 +  @n_PACKCASECNT2 + @n_PACKCASECNT3 + @n_PACKCASECNT4 + @n_PACKCASECNT6 +   
   --                     @n_PACKCASECNT12 + @n_PACKCASECNT24 + @n_PACKCASECNT48       --CS01  
     SET @n_TTLPACKCNT =  @n_PACKCASECNT1 + @n_PACKCASECNT2_FC + @n_PACKCASECNT2_LC + @n_PACKCASECNT3_FC + @n_PACKCASECNT3_LC + @n_PACKCASECNT4_FC + @n_PACKCASECNT4_LC  
                       + @n_PACKCASECNT6_FC + @n_PACKCASECNT6_LC + @n_PACKCASECNT12_FC + @n_PACKCASECNT12_LC + @n_PACKCASECNT24_FC + @n_PACKCASECNT24_LC  
        + @n_PACKCASECNT48_FC + @n_PACKCASECNT48_LC  --CS01  
  
    INSERT INTO #TEMPEXTORDUOM (ExtenOrderkey ,  
                                   PACKCASECNT1,  
           PACKCASECNT2,  
           PACKCASECNT2_FC,  
           PACKCASECNT2_LC,  
                                PACKCASECNT3,  
           PACKCASECNT3_FC,  
           PACKCASECNT3_LC,  
           PACKCASECNT4,  
           PACKCASECNT4_FC,  
           PACKCASECNT4_LC,  
           PACKCASECNT6,  
           PACKCASECNT6_FC,  
           PACKCASECNT6_LC,  
           PACKCASECNT12,  
           PACKCASECNT12_FC,  
           PACKCASECNT12_LC,  
           PACKCASECNT24,  
           PACKCASECNT24_FC,  
           PACKCASECNT24_LC,  
           PACKCASECNT48,  
           PACKCASECNT48_FC,  
           PACKCASECNT48_LC,  
           TTLPACKCNT)  
 values (@c_ExtenOrderkey,@n_PACKCASECNT1 ,@n_PACKCASECNT2 ,@n_PACKCASECNT2_FC,@n_PACKCASECNT2_LC,  
         @n_PACKCASECNT3 , @n_PACKCASECNT3_FC,@n_PACKCASECNT3_LC,  
   @n_PACKCASECNT4 , @n_PACKCASECNT4_FC,@n_PACKCASECNT4_LC,  
         @n_PACKCASECNT6,  @n_PACKCASECNT6_FC ,@n_PACKCASECNT6_LC,  
   @n_PACKCASECNT12, @n_PACKCASECNT12_FC,@n_PACKCASECNT12_LC,  
   @n_PACKCASECNT24, @n_PACKCASECNT24_FC,@n_PACKCASECNT24_LC,  
   @n_PACKCASECNT48, @n_PACKCASECNT48_FC,@n_PACKCASECNT48_LC,  
   @n_TTLPACKCNT)  
  
  
  
   FETCH NEXT FROM CUR_RESULT INTO @c_PreExtenOrderkey,@n_recgrp   
   END   
   close CUR_RESULT  
   deallocate CUR_RESULT  
      
    SELECT * FROM #TEMPEXTORDUOM   
       
    DROP TABLE #TEMPEXTORD    
    DROP TABLE #TEMPEXTORDUOM    
     
   WHILE @@TRANCOUNT > 0     
      COMMIT TRAN    
     
   WHILE @@TRANCOUNT < @nStartTranCount     
      BEGIN TRAN    
      
 END /* main procedure */    

GO