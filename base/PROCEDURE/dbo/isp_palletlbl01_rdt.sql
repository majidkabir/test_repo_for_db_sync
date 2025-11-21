SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Palletlbl01_rdt                                    */
/* Creation Date: 14-DEC-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15764 [RG] LOGITECH Pallet label new                    */
/*        :                                                             */
/* Called By: r_dw_pallet_label_rdt                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 21-APR-2021  CSCHONG   1.1 WMS-15764 fix duplicate serialno (CS01)   */
/* 06-JUL-2021  CSCHONG   1.2 WMS-17415 add new field (CS02)            */
/* 12-JUN-2023  WinSern   1.3 JSM-155674MaxLine=40,removedpickslip(ws01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_Palletlbl01_rdt]
           @c_PalletKey   NVARCHAR(30)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_PLTKey          NVARCHAR(30)
         , @c_storerkey       NVARCHAR(20)
         , @c_sku             NVARCHAR(20)  
         , @n_TTLCase         INT
         , @c_caseid          NVARCHAR(20)  --WL01
         , @n_Qty             INT           --WL01
        
   SET @n_StartTCnt = @@TRANCOUNT
   
   SET @n_TTLCase = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

  DECLARE  @c_getpalletkey      NVARCHAR(30)
          ,@c_SN             NVARCHAR(20)
          ,@c_SNGRP          NVARCHAR(1000)
          ,@n_RECGRP         INT
          ,@n_CTNSN          INT
          ,@n_MAXLINE        INT
          ,@n_LineNO         INT
          ,@n_ROWID          INT
          ,@c_Delimiter      NVARCHAR(1)
          ,@n_MAXROWNO       INT
          ,@c_recperline     INT
          ,@c_SN01           NVARCHAR(20)
          ,@c_SN02           NVARCHAR(20)
          ,@c_SN03           NVARCHAR(20)
          ,@c_SN04           NVARCHAR(20) 
          ,@c_SN05           NVARCHAR(20)  
          ,@n_newline        INT
          ,@n_RecPerLine     INT
          ,@c_Pickslipno     NVARCHAR(20)
          ,@n_intFlag        INT
          ,@n_RecGrpCnt      INT
          ,@n_TTLLine        INT
          ,@c_GetSN          NVARCHAR(50)
          ,@n_TTLpage        INT          
          ,@n_CurrentPage    INT


SET @n_MAXLINE = 40  --(ws01) 
SET @n_LineNO  = 0
SET @c_SNGRP = ''
SET @c_Delimiter = ','
SET @n_MAXROWNO = 1
SET @n_newline  = 1
SET @n_RecPerline = 5
SET @c_SN01 = ''
SET @c_SN02 = ''
SET @c_SN03 = ''
SET @c_SN04 = ''
SET @c_SN05 = ''
SET @n_intFlag = 1
SET @n_TTLLine = 1
SET @c_GetSN = ''
SET @n_TTLpage = 1
SET @n_CurrentPage = 1
 

CREATE TABLE #PACKSN   
         ( ROWID           INT IDENTITY (1,1) NOT NULL
         , PICKSLIPNO      NVARCHAR(20) NULL   
         , SKU             NVARCHAR(20) NULL  
         , Altsku          NVARCHAR(20) NULL  
         , Palletkey       NVARCHAR(30) NULL 
         , SDESCR          NVARCHAR(250) NULL
         , SN              NVARCHAR(50) NULL
         , CCompany        NVARCHAR(45) NULL)    --CS02
    --     , MergeSN         NVARCHAR(1000) NULL  
   --      , CTNSN           INT
   --      , RECGRP          INT) 

CREATE TABLE #PACKSNFINAL   
         ( ROWID           INT IDENTITY (1,1) NOT NULL
         , PICKSLIPNO      NVARCHAR(20) NULL   
         , SKU             NVARCHAR(20) NULL  
         , Altsku          NVARCHAR(20) NULL  
         , Palletkey       NVARCHAR(30) NULL 
         , SDESCR          NVARCHAR(250) NULL
         , SN              NVARCHAR(50) NULL
         , MergeSN         NVARCHAR(1000) NULL  
         , CTNSN           INT
         , RECGRP          INT
         , CCompany        NVARCHAR(45) NULL)    --CS02 

CREATE TABLE #PACKSNBYGRP   
         ( ROWID           INT IDENTITY (1,1) NOT NULL
         , PICKSLIPNO      NVARCHAR(20) NULL   
         , SKU             NVARCHAR(20) NULL  
         , Palletkey       NVARCHAR(30) NULL 
         , SN01            NVARCHAR(50) NULL
         , SN02            NVARCHAR(50) NULL  
         , SN03            NVARCHAR(50) NULL  
         , SN04            NVARCHAR(50) NULL  
         , SN05            NVARCHAR(50) NULL  
         , RECGRP          INT) 

CREATE TABLE #PACKSNGRP
( Palletkey       NVARCHAR(30) NULL ,
  RECGRP          INT,
  SNCTN           INT,
  GrpSN           NVARCHAR(1000) NULL
) 

insert into #PACKSN (PICKSLIPNO,sku,Altsku,Palletkey,SDESCR,SN,CCompany)--,MergeSN,CTNSN,RECGRP) --CS02
select pk.PickSlipNo,pk.sku,sku.ALTSKU,pl.PalletKey,sku.DESCR,ISNULL(m.SerialNo,s.serialno),oh.C_Company--,'',0--count(m.SerialNo),count(distinct oh.OrderKey)  --CS01
--,0--,((Row_Number() OVER (PARTITION BY pk.PickSlipNo,pl.PalletKey ORDER BY m.SerialNo Asc)-1)/@n_MAXLINE +1) as recgrp
from packdetail(nolock) pk 
left join packheader (nolock) ph on ph.PickSlipNo=pk.PickSlipNo and pk.StorerKey=ph.StorerKey
left join orders (nolock) oh on   ph.StorerKey=oh.StorerKey and ph.OrderKey=oh.OrderKey

left join SerialNo(nolock) s on  s.pickslipno =pk.PickSlipNo and pk.StorerKey =s.StorerKey and pk.sku=s.sku and s.CartonNo=pk.CartonNo
left join MasterSerialNo(nolock) m on s.Storerkey=m.StorerKey and m.ParentSerialNo=s.SerialNo and  s.sku=m.sku 
left join sku (nolock) on pk.sku=sku.sku and sku.StorerKey=pk.StorerKey 
left join PALLETdetail(nolock) pl on pl.StorerKey=pk.StorerKey and  pk.LabelNo=pl.CaseId 
--where s.pickslipno='P109686363'
where pl.palletkey=@c_PalletKey
group by pk.PickSlipNo,pk.sku,sku.ALTSKU,pl.PalletKey,sku.DESCR,m.SerialNo,s.SerialNo,oh.C_Company
order by m.SerialNo


insert into #PACKSNFINAL (PICKSLIPNO,sku,Altsku,Palletkey,SDESCR,SN,MergeSN,CTNSN,RECGRP,CCompany)
SELECT psn.PickSlipNo AS psnno,psn.sku AS sku,psn.ALTSKU AS altsku,psn.PalletKey AS palletkey,psn.SDESCR AS descr,
       ISNULL(m.serialno,psn.SN),'',0,((Row_Number() OVER (PARTITION BY psn.PalletKey ORDER BY ISNULL(m.serialno,psn.SN) Asc)-1)/@n_MAXLINE +1) as recgrp		--(ws01 removed PARTITION BY psn.PickSlipNo) 
      ,psn.CCompany
FROM #PACKSN PSN
LEFT JOIN dbo.MasterSerialNo m WITH (NOLOCK) ON m.ParentSerialNo=psn.SN
ORDER BY ISNULL(m.serialno,psn.SN)


select @n_MAXROWNO = MAX(rowid)
from #PACKSNFINAL

--SELECT * FROM #PACKSNFINAL

      DECLARE CUR_SN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT ROWID,PALLETKEY,SN,RECGRP  
      FROM #PACKSNFINAL  
      --WHERE PALLETKEY = @c_Palletkey
     ORDER BY SN,RECGRP
     OPEN CUR_SN  
     
   FETCH NEXT FROM CUR_SN INTO @n_ROWID,@c_getpalletkey,@c_SN, @n_RECGRP  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

    --IF @n_RECGRP = 5
    --BEGIN
   --   select @n_ROWID '@n_ROWID',@n_MAXROWNO '@n_MAXROWNO',(@n_ROWID%@n_MAXLINE) '(@n_ROWID%@n_MAXLINE)'
    --END 

    IF @n_MAXROWNO > 1 AND (@n_ROWID%@n_MAXLINE) = 1
    BEGIN
      SET @c_SNGRP = ''
    END

   --IF @n_RECGRP = @n_LineNO
   --BEGIN
       IF (@n_ROWID%@n_MAXLINE) = 1 AND @n_MAXROWNO > 1
       BEGIN

          SET @c_SNGRP =  @c_SN + @c_delimiter
          SET @n_LineNO = @n_LineNO + 1 
       END
       ELSE IF  (@n_ROWID%@n_MAXLINE) > 1 AND @n_ROWID <> @n_MAXROWNO
       BEGIN

          SET @c_SNGRP =  @c_SNGRP  + @c_SN + @c_delimiter
          SET @n_LineNO = @n_LineNO + 1 
       END
       ELSE IF (@n_ROWID%@n_MAXLINE) = 0 OR @n_ROWID = @n_MAXROWNO
       BEGIN

           SET @c_SNGRP =  @c_SNGRP + @c_SN
           SET @n_LineNO = @n_LineNO + 1 
 
            INSERT INTO #PACKSNGRP  (Palletkey,RECGRP,SNCTN,GrpSN)
            VALUES(@c_palletkey,@n_RECGRP,@n_LineNO,@c_SNGRP)

            SET @c_SNGRP = ''
            SET @n_LineNO = 0 
       END

  FETCH NEXT FROM CUR_SN INTO @n_ROWID,@c_getpalletkey,@c_SN, @n_RECGRP    
  END  
  CLOSE CUR_SN  
  DEALLOCATE CUR_SN 

--SELECT * FROM #PACKSNGRP

DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT pickslipno, sku,palletkey--,recgrp    
   FROM #PACKSNFINAL 
   ORDER BY pickslipno, sku,palletkey--,recgrp                
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_pickslipno,@c_sku,@c_palletkey--,@n_recgrp      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN 
  
 --  SET @n_RecGrpCnt = 1
       --CS01 START
        SET @c_SN01 = ''
        SET @c_SN02 = ''
        SET @c_SN03 = ''
        SET @c_SN04 = ''
        SET @c_SN05 = '' 
       --CS01 END 

   IF NOT EXISTS (SELECT 1 
                  FROM #PACKSNBYGRP 
                  WHERE --Pickslipno = @c_pickslipno AND   --(ws01)
				  sku = @c_sku
                  AND palletkey = @c_palletkey)-- AND recgrp = @n_recgrp)                             
   BEGIN
       INSERT INTO #PACKSNBYGRP (PICKSLIPNO, SKU, Palletkey, SN01, SN02, SN03 , SN04, SN05, RECGRP )   
       VALUES(@c_pickslipno,@c_sku,@c_palletkey,'','','','','',@n_CurrentPage)
   END
   --SET @n_RecGrpCnt = 1
     SELECT @n_RecGrpCnt = COUNT (1)
     FROM #PACKSNFINAL   
     WHERE --pickslipno = @c_pickslipno AND    --(ws01)
	 palletkey = @c_palletkey   
     --AND recgrp = @n_recgrp
   
   SET @n_TTLpage = FLOOR(@n_RecGrpCnt / @n_MAXLINE ) + CASE WHEN @n_RecGrpCnt % @n_MAXLINE > 0 THEN 1 ELSE 0 END
   SET @n_TTLLine = FLOOR(@n_RecGrpCnt / @n_RecPerline ) + CASE WHEN @n_RecGrpCnt % @n_RecPerline > 0 THEN 1 ELSE 0 END   
  
--  select @n_RecGrpCnt '@n_RecGrpCnt',@n_recgrp '@n_recgrp', @n_TTLLine '@n_TTLLine', @n_TTLpage '@n_TTLpage'
  -- select @n_TTLLine '@n_TTLLine'

   WHILE @n_intFlag <= @n_RecGrpCnt             
     BEGIN    

 --  select @n_intFlag '@n_intFlag'

       IF @n_intFlag > @n_RecPerline AND (@n_intFlag%@n_RecPerline) = 1 --AND @c_LastRec = 'N'  
       BEGIN  
       
          SET @n_newline = @n_newline + 1  
          IF @n_intFlag > @n_MAXLINE AND (@n_intFlag%@n_MAXLINE) = 1
          BEGIN
            SET @n_CurrentPage = @n_CurrentPage + 1
          END 
          IF (@n_newline>@n_TTLLine)   
          BEGIN  
             BREAK;  
          END     
          
          INSERT INTO #PACKSNBYGRP (PICKSLIPNO, SKU, Palletkey, SN01, SN02, SN03 , SN04, SN05, RECGRP )   
          VALUES(@c_pickslipno,@c_sku,@c_palletkey,'','','','','',@n_CurrentPage)
           
            --CS01 START
            SET @c_SN01 = ''
            SET @c_SN02 = ''
            SET @c_SN03 = ''
            SET @c_SN04 = ''
            SET @c_SN05 = '' 
            --CS01 END

       END     

        SELECT @c_GetSN = SN  
        FROM #PACKSNFINAL   
        WHERE RowID = @n_intFlag  
        GROUP BY SN
        ORDER BY SN
   --   select @c_GetSN '@c_GetSN'
      IF (@n_intFlag%@n_RecPerline) = 1 --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_SN01    = @c_GetSN  
      END

      ELSE IF (@n_intFlag%@n_RecPerline) = 2  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_SN02    = @c_GetSN   
      END   

      ELSE IF (@n_intFlag%@n_RecPerline) = 3  --AND @n_recgrp = @n_CurrentPage  
      BEGIN            
         SET @c_SN03    = @c_GetSN  
      END 

      ELSE IF (@n_intFlag%@n_RecPerline) = 4  --AND @n_recgrp = @n_CurrentPage  
      BEGIN             
         SET @c_SN04    = @c_GetSN       
      END

      ELSE IF (@n_intFlag%@n_RecPerline) = 0  --AND @n_recgrp = @n_CurrentPage  
      BEGIN          
         SET @c_SN05    = @c_GetSN      
      END 

   UPDATE #PACKSNBYGRP                    
   SET  SN01 = @c_SN01
      ,SN02 = @c_SN02
      ,SN03 = @c_SN03
      ,SN04 = @c_SN04
      ,SN05 = @c_SN05 
    WHERE ROWID = @n_newline   
             

        --SET @c_SN01 = ''
        --SET @c_SN02 = ''
        --SET @c_SN03 = ''
        --SET @c_SN04 = ''
        --SET @c_SN05 = '' 

        SET @n_intFlag = @n_intFlag + 1    
  
        IF @n_intFlag > @n_RecGrpCnt  
        BEGIN  
          BREAK;  
        END  

        
      END  

   --SET @n_intFlag = 1
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_pickslipno,@c_sku,@c_palletkey--,@n_recgrp  
          
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop

--select * from #PACKSN

--select * from #PACKSNGRP

--SELECT DISTINCT PSN.PICKSLIPNO, PSN.SKU,  PSN.Altsku,PSN.Palletkey, PSN.SDESCR ,PSN.SN,PSNG.GrpSN,
--                CAST(PSNG.SNCTN as NVARCHAR(10)) as SNCTN ,PSN.RECGRP
--FROM #PACKSN PSN
--JOIN  #PACKSNGRP PSNG ON PSNG.Palletkey = PSN.Palletkey AND PSNG.RECGRP = PSN.RECGRP
--ORDER BY PSN.PICKSLIPNO,PSN.Palletkey,PSN.SN,PSN.RECGRP

--SELECT DISTINCT PSN.PICKSLIPNO,  PSN.Altsku,PSN.Palletkey, PSN.SDESCR ,PSN.SKU, PSN.SN,PSNG.GrpSN,
--                CAST(PSNG.SNCTN as NVARCHAR(10)) as SNCTN ,PSN.RECGRP
--FROM #PACKSN PSN
--JOIN  #PACKSNGRP PSNG ON PSNG.Palletkey = PSN.Palletkey AND PSNG.RECGRP = PSN.RECGRP
--ORDER BY PSN.PICKSLIPNO,PSN.Palletkey,PSN.SN,PSN.RECGRP

SELECT  PSN.PICKSLIPNO, PSN.SKU , PSN.Altsku,PSN.Palletkey, PSN.SDESCR,PSNG.GrpSN,PSNG.SNCTN,PSN.RECGRP,
                PBG.SN01,PBG.SN02,PBG.SN03,PBG.SN04,PBG.SN05,psn.CCompany       --CS02
FROM #PACKSNFINAL PSN
JOIN  #PACKSNGRP PSNG ON PSNG.Palletkey = PSN.Palletkey AND PSNG.RECGRP = PSN.RECGRP
JOIN #PACKSNBYGRP PBG ON PBG.PICKSLIPNO = PSN.PICKSLIPNO AND PBG.Palletkey = PSN.Palletkey 
                     AND PBG.SKU = PSN.SKU AND PBG.RECGRP=PSN.RECGRP
GROUP BY PSN.PICKSLIPNO, PSN.SKU , PSN.Altsku,PSN.Palletkey, PSN.SDESCR, PSNG.GrpSN,PSNG.SNCTN,PSN.RECGRP,
                PBG.SN01,PBG.SN02,PBG.SN03,PBG.SN04,PBG.SN05,psn.CCompany        --CS02
ORDER BY PSN.PICKSLIPNO, PSN.SKU , PSN.Altsku,PSN.Palletkey, PSN.SDESCR, PSNG.GrpSN,PSNG.SNCTN,PSN.RECGRP,
                PBG.SN01,PBG.SN02,PBG.SN03,PBG.SN04,PBG.SN05

drop table #PACKSN
drop table #PACKSNGRP         
drop table #PACKSNBYGRP
DROP TABLE #PACKSNFINAL

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO