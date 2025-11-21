SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/  
/* Stored Procedure: isp_loadlist_rpt01                                  */  
/* Creation Date: 2020-07-01                                             */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-13914 - JP_HM_LoadList_DW_CR                             */  
/*                                                                       */  
/* Called By: r_loadlist_rpt01                                           */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author  Ver   Purposes                                    */  
/* 05-Mar-2021 LZG     1.2   INC1445710 - Order by Loc (ZG01)            */
/* 29-Aug-2022 WyeChun 1.3   JSM-86604 - Add LogicalLocation (WC01)      */  
/* 04-Oct-2023 JihHaur 1.4   JSM-181688 - Add Loc.Loc (JH01)             */ 
/*************************************************************************/  
CREATE PROC [dbo].[isp_loadlist_rpt01]  
         (  @c_loadkeyfrom    NVARCHAR(10) --WL01    
         ,  @c_loadkeyto    NVARCHAR(10) --WL01    
         ,  @c_type     NVARCHAR(10)= '')    
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE --@c_storerkey  NVARCHAR(10)  
          @c_storerkeyfrom  NVARCHAR(10) --WL01  
         ,@c_storerkeyto    NVARCHAR(10) --WL01  
         ,@n_NoOfLine       INT  
         ,@n_recgrpsort     INT            
  
  
   SET @n_NoOfLine = 80  
  
  
  CREATE TABLE #TMPLOADBYORD (RowNo       INT,  
                              Loadkey     NVARCHAR(20),  
                              Orderkey    NVARCHAR(20) null,   
                              TotalQty    INT null,   
                              OHROUTE     NVARCHAR(20) null,  
                              recgrp      INT)  
     
   --WL01 START  
   SELECT @c_storerkeyfrom = MIN(OH.Storerkey)  
         ,@c_storerkeyto = MAX(OH.Storerkey)  
   FROM ORDERS OH (NOLOCK)  
   WHERE Loadkey BETWEEN @c_loadkeyfrom AND @c_loadkeyto  
   --WL01 END  
  
   IF @c_type = '' OR @c_type = '1'  
   BEGIN  
      INSERT INTO  #TMPLOADBYORD (RowNo,Loadkey,Orderkey,TotalQty,OHROUTE,recgrp)  
      SELECT row_number() over(order by OrdHD.LoadKey,Loc.Score , Loc.LogicalLocation, Loc.Loc, OrdHD.Orderkey, OrdHD.Route  ) as [RowNo] ,          -- ZG01 --WL01 (Added Loadkey)  
              OrdHD.LoadKey AS Loadkey, OrdHD.OrderKey AS Orderkey,  
              Sum( OrdDT.OriginalQty ) [TotalQty] , OrdHD.Route AS OHROUTE,  
             (Row_Number() OVER (PARTITION BY OrdHD.LoadKey  ORDER BY Loc.Score , Loc.LogicalLocation, Loc.Loc , OrdHD.Route Asc)-1)/@n_NoOfLine+1 AS recgrp   /*WC01    JH01 (Added  Loc.Loc)*/
      FROM ORDERS AS OrdHD WITH (NOLOCK)  
      JOIN ORDERDETAIL as OrdDT WITH (NOlock)  
          ON OrdHD.StorerKey = OrdDT.StorerKey  
         AND OrdHD.OrderKey = OrdDt.OrderKey  
      JOIN PICKDETAIL AS PickDT WITH (nolock)  
          ON OrdDT.StorerKey = PickDT.Storerkey  
         AND OrdDT.OrderKey = PickDT.OrderKey  
         AND OrdDT.OrderLineNumber = PickDT.OrderLineNumber  
      JOIN LOC WITH (nolock)  
          ON PickDT.Loc = Loc.Loc  
         AND LOC.Facility = 'HM'  
      WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto --WL01  
         AND OrdHD.LoadKey BETWEEN @c_loadkeyfrom AND @c_loadkeyto --WL01  
      GROUP BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route , Loc.Loc , Loc.LogicalLocation, Loc.Score         
      ORDER BY OrdHD.LoadKey, Loc.Score , Loc.LogicalLocation, Loc.Loc, OrdHD.Orderkey        --WL01 (Added Loadkey)  
  
  
   END  
   ELSE  
   BEGIN  
      INSERT INTO  #TMPLOADBYORD (RowNo,Loadkey,Orderkey,TotalQty,OHROUTE,recgrp)  
      SELECT row_number() over(order by OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route) AS [RowNo] ,  
             OrdHD.LoadKey AS Loadkey, OrdHD.OrderKey AS Orderkey, Sum( OrdDT.OriginalQty ) [TotalQty] ,  
             OrdHD.Route AS OHROUTE,  
             (Row_Number() OVER (PARTITION BY OrdHD.LoadKey  ORDER BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route Asc)-1)/@n_NoOfLine+1 AS recgrp  
      FROM ORDERS AS  OrdHD WITH (NOLOCK)  
      JOIN ORDERDETAIL AS OrdDT (NOlock)  
          ON OrdHD.StorerKey = OrdDT.StorerKey  
         AND OrdHD.OrderKey = OrdDt.OrderKey  
      WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto --WL01  
         AND OrdHD.LoadKey BETWEEN @c_loadkeyfrom AND @c_loadkeyto --WL01  
      GROUP BY OrdHD.LoadKey , OrdHD.OrderKey , OrdHD.Route  
      ORDER BY OrdHD.LoadKey ,OrdHD.OrderKey  
  
   END  
  
  CREATE TABLE #TMPSPLITLOAD (  
                              Loadkey       NVARCHAR(20),  
                              OrderkeyGrp1  NVARCHAR(20) null ,  
                              Rownogrp1     INT null,   
                              OrderkeyGrp2  NVARCHAR(20) null,  
                              recgrp        INT,  
                              Rownogrp2     INT null )  
  
declare @n_maxline int  
       ,@n_rowno int  
       ,@c_loadkey nvarchar(20)  
       ,@c_orderkey nvarchar(20)  
       ,@n_recgrp int  
       ,@n_maxrec int  
  
   --select *,DENSE_RANK() OVER ( ORDER BY rowno,loadkey,orderkey) as rowrec,ROW_NUMBER() OVER ( PARTITION BY loadkey ORDER BY rowno,loadkey,orderkey)  as recgrpsort  
   --from #TMPLOADBYORD  
  
  --SELECT DISTINCT rowno,loadkey,orderkey,recgrp    
  --                 ,ROW_NUMBER() OVER ( PARTITION BY loadkey ORDER BY rowno,loadkey,orderkey)   
  -- FROM   #TMPLOADBYORD ORD     
  -- order by rowno  
  
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT rowno,loadkey,orderkey,recgrp    
                   ,ROW_NUMBER() OVER ( PARTITION BY loadkey ORDER BY rowno,loadkey,orderkey)   
   FROM   #TMPLOADBYORD ORD     
   order by rowno  
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_loadkey,@c_orderkey,@n_recgrp,@n_recgrpsort      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN     
  
    IF @n_recgrpsort <= (@n_NoOfLine/2)   
    BEGIN  
        INSERT INTO #TMPSPLITLOAD (Loadkey,recgrp,Rownogrp1,Rownogrp2, OrderkeyGrp1,OrderkeyGrp2)  
        VALUES(@c_loadkey,@n_recgrp,@n_recgrpsort,'',@c_orderkey,'')    
    END  
    ELSE IF @n_recgrpsort > (@n_NoOfLine/2) AND @n_recgrpsort <= @n_NoOfLine  
    BEGIN  
        UPDATE #TMPSPLITLOAD  
        SET Rownogrp2 = @n_recgrpsort  
           ,OrderkeyGrp2 = @c_orderkey  
        WHERE loadkey = @c_loadkey  
        AND recgrp = @n_recgrp  
       -- AND OrderkeyGrp2 = ''   
        AND Rownogrp1 = @n_recgrpsort -(@n_NoOfLine/2)   
    END  
    ELSE IF @n_recgrpsort > @n_NoOfLine  
    BEGIN  
         set @n_maxrec = 1  
         select @n_maxrec = MAX(recgrp)  
         FROM   #TMPSPLITLOAD  
         where loadkey = @c_loadkey  
  
         IF @n_recgrp =  @n_maxrec + 1 OR @n_recgrp =  @n_maxrec  
         BEGIN  
             --select @n_rowno%@n_maxline '@n_rowno%@n_maxline'  
              IF (@n_recgrpsort%@n_NoOfLine) <= (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) > 0  
              BEGIN  
                    INSERT INTO #TMPSPLITLOAD (Loadkey,recgrp,Rownogrp1,Rownogrp2, OrderkeyGrp1,OrderkeyGrp2)  
                    VALUES(@c_loadkey,@n_recgrp,@n_recgrpsort,'',@c_orderkey,'')    
              END  
              ELSE IF (@n_recgrpsort%@n_NoOfLine) = 0 OR ((@n_recgrpsort%@n_NoOfLine) > (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) <= @n_NoOfLine)  
              BEGIN  
  
                  UPDATE #TMPSPLITLOAD  
                  SET Rownogrp2 = @n_recgrpsort  
                     ,OrderkeyGrp2 = @c_orderkey  
WHERE loadkey = @c_loadkey  
                   AND recgrp = @n_recgrp  
                   -- AND OrderkeyGrp2 = ''   
                  AND Rownogrp1 = CASE WHEN (@n_recgrpsort%@n_NoOfLine) = 0 THEN (@n_recgrpsort - @n_NoOfLine)+(@n_NoOfLine/2)   
                                       WHEN @n_recgrpsort <= 200 THEN (@n_recgrpsort%@n_NoOfLine)+(@n_NoOfLine/2)   
                                       ELSE (@n_recgrpsort%@n_NoOfLine)+((@n_NoOfLine)*(@n_recgrp-1)-(@n_NoOfLine/2)) END  
              END   
         END  
    END  
  
    FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_loadkey,@c_orderkey,@n_recgrp ,@n_recgrpsort      
   END     
  
  CLOSE CUR_RESULT  
  DEALLOCATE CUR_RESULT  
  
      
  
    SELECT loadkey as loadkey,  
           orderkeygrp1 as orderkeygrp1,  
           CAST(rownogrp1 as NVARCHAR(10) ) AS rownogrp1,  
           orderkeygrp2 as orderkeygrp2,   
           recgrp as recgrp,  
           CASE WHEN ISNULL(orderkeygrp2,'') <> '' THEN CAST(rownogrp2 as NVARCHAR(10) ) ELSE '' END AS rownogrp2  
    FROM  #TMPSPLITLOAD  
  
drop table #TMPLOADBYORD  
drop table #TMPSPLITLOAD  
  
QUIT_SP:  
END  


GO