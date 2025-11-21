SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RDTPPA_AuditTrail01					               */
/* Creation Date: 05-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: CHEWKP                                                   */
/*                                                                      */
/* Purpose: AuditTrail Report from RDTPPA                               */
/*                                                                      */
/* Called By: report dw = r_dw_rdtppa_audittrail01                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*11-06-2010	 ChewKP	  1.1	  Addition information requested (ChewKP01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_RDTPPA_AuditTrail01]  (
  @c_Storerkey NVARCHAR(15),
  @c_ReportType NVARCHAR(1), -- 1 By PickSlipNo
                         -- 2 By Loadkey
  @c_KeyStart  NVARCHAR(10),  
  @c_KeyEnd    NVARCHAR(10)
) 
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Declare temp tables
   CREATE TABLE #TempRDTPPA  (
      StorerKey        NVARCHAR(15) NULL,
      RefKey           NVARCHAR(10) NULL,
      Sku              VARCHAR (20) NULL,
	   Descr            VARCHAR (60) NULL,
	   PickedQty        INT NULL,
	   CQty             INT NULL,
		ExceptionQty     INT NULL,
	   UserName         VARCHAR (18) NULL,
	   MinTime			  DATETIME NULL,		
		MaxTime			  DATETIME NULL
	   )
      
	DECLARE @c_RDTRefKey NVARCHAR(10)
	, @c_RDTUserName     NVARCHAR(18)
	, @d_MinTime         DATETIME   
	, @d_MaxTime         DATETIME
	

      -- Insert Data for Refkey    
      IF @c_ReportType = '1'
      BEGIN
   		INSERT INTO #TempRDTPPA (StorerKey, RefKey,  Sku,   Descr, 
   		                          PickedQty, CQty, ExceptionQty, UserName
   		                           )
         SELECT PD.Storerkey, PD.PickSlipNo, PD.SKU, SKU.Descr,  Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) , RDTPPA.CQTY , (Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) - RDTPPA.CQTY)
         , RDTPPA.UserName
         FROM PICKDETAIL PD (NOLOCK)
         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         INNER JOIN RDT.RDTPPA RDTPPA (NOLOCK) ON (RDTPPA.PickSlipNo = PD.PickSlipNo And RDTPPA.SKU = PD.SKU)
         WHERE PD.PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd
               AND PD.Storerkey = @c_Storerkey
         GROUP BY PD.Storerkey, PD.PickSlipNo, PD.SKU, SKU.Descr, Pack.CaseCnt, RDTPPA.CQTY , RDTPPA.UserName --,RDTPPAAUDIT.PickSlipNo
         HAVING  Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) <> RDTPPA.CQty
         
         --- SELECT NON EXCEPTION RECORDS ---
         INSERT INTO #TempRDTPPA (StorerKey, RefKey,  UserName )
         SELECT DISTINCT PD.Storerkey, PD.PickSlipNo, 
          RDTPPA.UserName
         FROM PICKDETAIL PD (NOLOCK)
         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         INNER JOIN RDT.RDTPPA RDTPPA (NOLOCK) ON (RDTPPA.PickSlipNo = PD.PickSlipNo And RDTPPA.SKU = PD.SKU)
         WHERE PD.PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd
               AND PD.Storerkey = @c_Storerkey
					AND PD.PickSlipNo NOT IN (SELECT Refkey FROM #TempRDTPPA ) 
         GROUP BY PD.Storerkey, PD.PickSlipNo, Pack.CaseCnt, RDTPPA.CQTY , RDTPPA.UserName --,RDTPPAAUDIT.PickSlipNo
         HAVING  Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) = RDTPPA.CQty
      END
      ELSE
      BEGIN
         INSERT INTO #TempRDTPPA (StorerKey, RefKey,  Sku,   Descr, 
   		                          PickedQty, CQty, ExceptionQty, UserName
   		                           )
         SELECT PD.Storerkey, LP.Loadkey, PD.SKU, SKU.DESCR, 
         Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) ,RDTPPA.CQTY,
         (Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) - RDTPPA.CQTY), RDTPPA.UserName
         FROM LOADPLAN LP (NOLOCK)
         INNER JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = LP.LOADKEY
         INNER JOIN ORDERS O (NOLOCK) ON  (O.LOADKEY = LPD.LOADKEY AND O.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN ORDERDETAIL OD (NOLOCK) ON  (OD.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = O.ORDERKEY AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)
         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         INNER JOIN RDT.RDTPPA RDTPPA (NOLOCK) ON (RDTPPA.LOADKEY = LP.LOADKEY AND RDTPPA.SKU = PD.SKU)
         WHERE LP.Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd
               AND PD.Storerkey = @c_Storerkey
         GROUP BY PD.Storerkey, LP.Loadkey, PD.SKU, SKU.DESCR, Pack.CaseCnt ,RDTPPA.CQTY, RDTPPA.UserName
         HAVING  Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) <> RDTPPA.CQty
         
         --- SELECT NON EXCEPTION RECORDS ---
         INSERT INTO #TempRDTPPA (StorerKey, RefKey,  UserName )
         SELECT DISTINCT PD.Storerkey, LP.Loadkey, 
         RDTPPA.UserName
         FROM LOADPLAN LP (NOLOCK)
         INNER JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = LP.LOADKEY
         INNER JOIN ORDERS O (NOLOCK) ON  (O.LOADKEY = LPD.LOADKEY AND O.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN ORDERDETAIL OD (NOLOCK) ON  (OD.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = O.ORDERKEY AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)
         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         INNER JOIN RDT.RDTPPA RDTPPA (NOLOCK) ON (RDTPPA.LOADKEY = LP.LOADKEY AND RDTPPA.SKU = PD.SKU)
         WHERE LP.Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd
               AND PD.Storerkey = @c_Storerkey
					AND LP.Loadkey NOT IN (SELECT Refkey FROM #TempRDTPPA ) 
         GROUP BY PD.Storerkey, LP.Loadkey,  Pack.CaseCnt ,RDTPPA.CQTY, RDTPPA.UserName
         HAVING  Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) = RDTPPA.CQty
      END
      


      DECLARE Cur_RDTPPA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      
      SELECT RefKey, Username From #TempRDTPPA
      Group By Refkey , Username 
      
      OPEN Cur_RDTPPA

      FETCH NEXT FROM Cur_RDTPPA INTO @c_RDTRefKey, @c_RDTUserName 
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         IF @c_ReportType = '1'
         BEGIN
            SELECT @d_MinTime = Min(convert(varchar,Adddate,120)) ,
                   @d_MaxTime = Max(convert(varchar,Adddate,120)) 
            FROM RDT.RDTPPA (NOLOCK)
            WHERE PickSlipNo = @c_RDTRefKey AND UserName = @c_RDTUserName
         END
         ELSE
         BEGIN
            SELECT @d_MinTime = Min(convert(varchar,Adddate,120)) ,
                   @d_MaxTime = Max(convert(varchar,Adddate,120)) 
            FROM RDT.RDTPPA (NOLOCK)
            WHERE Loadkey = @c_RDTRefKey AND UserName = @c_RDTUserName


         END
         
         UPDATE #TempRDTPPA
         SET MinTime = @d_MinTime , MaxTime = @d_MaxTime
         WHERE RefKey = @c_RDTRefKey AND UserName = @c_RDTUserName
         
         FETCH NEXT FROM Cur_RDTPPA INTO @c_RDTRefKey, @c_RDTUserName
      END

		CLOSE Cur_RDTPPA
		DEALLOCATE Cur_RDTPPA
      
      -- Include All Picked Item that within the provided key range and not yet post audit (Start) (ChewKP01) 
      IF @c_ReportType = '1' 
      BEGIN
         Insert Into #TempRDTPPA (Storerkey , Refkey , SKU , DESCR , PickedQty , CQty , ExceptionQty )
--         SELECT PD.Storerkey, PD.PickSlipNo , PD.SKU , SKU.DESCR, Round(Sum(PD.Qty) /  Pack.CaseCnt, 0), '0', Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) FROM PICKDETAIL PD (NOLOCK)
--         INNER JOIN SKU SKU (NOLOCK) ON (SKU.SKU = PD.SKU)
--         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
--         WHERE PD.PickSlipNo NOT IN (SELECT PickSlipNo FROM RDT.RDTPPA (NOLOCK) WHERE PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd ) 
--         AND PD.PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd 
--         AND PD.Storerkey = @c_Storerkey
--         Group by PD.Storerkey, PD.PickSlipNo , PD.SKU,  SKU.DESCR, PACK.CaseCnt

         SELECT PD.Storerkey, PD.PickSlipNo , PD.SKU , SKU.DESCR, Round(Sum(PD.Qty) /  Pack.CaseCnt, 0), '0', Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) FROM PICKDETAIL PD (NOLOCK)
         INNER JOIN SKU SKU (NOLOCK) ON (SKU.SKU = PD.SKU)
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         WHERE PD.SKU NOT IN (SELECT SKU FROM RDT.RDTPPA (NOLOCK) WHERE PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd ) 
         AND PD.PickSlipNo BETWEEN @c_KeyStart AND @c_KeyEnd 
         AND PD.Storerkey = @c_Storerkey
         Group by PD.Storerkey, PD.PickSlipNo , PD.SKU,  SKU.DESCR, PACK.CaseCnt


      END
      ELSE
      BEGIN
         Insert Into #TempRDTPPA (Storerkey , Refkey , SKU , DESCR , PickedQty , CQty , ExceptionQty )
--         SELECT O.Storerkey, LP.Loadkey,  PD.SKU , SKU.DESCR, Round(Sum(PD.Qty) /  Pack.CaseCnt, 0), '0', Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) FROM LOADPLAN LP (NOLOCK)
--         INNER JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = LP.LOADKEY
--         INNER JOIN ORDERS O (NOLOCK) ON  (O.LOADKEY = LPD.LOADKEY AND O.ORDERKEY = LPD.ORDERKEY)
--         INNER JOIN ORDERDETAIL OD (NOLOCK) ON  (OD.ORDERKEY = LPD.ORDERKEY)
--         INNER JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = O.ORDERKEY AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)
--         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
--         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
--         WHERE LP.LOADKEY NOT IN (SELECT Loadkey FROM RDT.RDTPPA (NOLOCK) WHERE Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd) 
--         AND LP.Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd  
--         AND O.Storerkey = @c_Storerkey
--         Group by O.Storerkey, LP.Loadkey , PD.SKU,  SKU.DESCR, PACK.CaseCnt

			SELECT O.Storerkey, LP.Loadkey,  PD.SKU , SKU.DESCR, Round(Sum(PD.Qty) /  Pack.CaseCnt, 0), '0', Round(Sum(PD.Qty) /  Pack.CaseCnt, 0) FROM LOADPLAN LP (NOLOCK)
         INNER JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = LP.LOADKEY
         INNER JOIN ORDERS O (NOLOCK) ON  (O.LOADKEY = LPD.LOADKEY AND O.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN ORDERDETAIL OD (NOLOCK) ON  (OD.ORDERKEY = LPD.ORDERKEY)
         INNER JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = O.ORDERKEY AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)
         INNER JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU
         INNER JOIN PACK (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY
         WHERE --LP.LOADKEY NOT IN (SELECT Loadkey FROM RDT.RDTPPA (NOLOCK) WHERE Loadkey BETWEEN '0000511553' AND '0000511553') 
			--AND 
			PD.SKU NOT IN ( SELECT SKU FROM RDT.RDTPPA (NOLOCK) WHERE Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd)
         AND LP.Loadkey BETWEEN @c_KeyStart AND @c_KeyEnd  
         AND O.Storerkey = @c_Storerkey
         Group by O.Storerkey, LP.Loadkey , PD.SKU,  SKU.DESCR, PACK.CaseCnt
      END
      -- Include All Picked Item that within the provided key range and not yet post audit (End) (ChewKP01) 

		
      SELECT Storerkey, RefKey, SKU,          Descr,
             PickedQty, CQty,   ExceptionQty, UserName,
				 MinTime, MaxTime,
             CAST( DATEDIFF ( minute , MinTime , MaxTime ) AS INT) AS Mins,
             CAST ((DATEDIFF ( minute , MinTime, MaxTime) / 60.00 ) AS Float(2) ) AS Hours,
             @c_ReportType
      FROM #TempRDTPPA
		ORDER By UserName
      
            
      DROP Table #TempRDTPPA 
		

END


GO