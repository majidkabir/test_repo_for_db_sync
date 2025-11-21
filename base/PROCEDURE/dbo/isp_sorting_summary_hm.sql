SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_Sorting_Summary_hm                             */  
/* Creation Date:11/01/2019                                             */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-7632 - [CN] H&M Sorting Summary report CR               */  
/*                                                                      */  
/* Called By: r_dw_sorting_summary_hm                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 2021-Apr-09 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS01)*/
/* 2021-Oct-11 MINGLE   1.2   WMS-18031 Add new field (ML01)            */
/* 06-Oct-2021 Mingle   1.2   DevOps Combine Script                     */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_Sorting_Summary_hm] (  
                 @c_pickslipno NVARCHAR(20)  
                          )  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
      SELECT ROW_NUMBER() OVER(ORDER BY PT.logicalname ASC)  as Num,  --partition by PD.pickslipno  
      OH.LoadKey AS Loadkey,  
      OH.orderkey as orderkey ,  
       --'*'+ OH.OrderKey + '*' as orderkeybar,  
      --OH.userdefine04 as trackingnum,   --CS01
      OH.TrackingNo AS trackingnum,       --CS01
     -- '*'+ OH.userdefine04 + '*' as trackingbar,  
      PD.pickslipno as pickslipno,  
      PD.Notes as Taskname,  
      SUM(PD.Qty) as orderpiece,   
      PT.logicalname as logicalname,
      SUM(CASE WHEN PD.Caseid = 'SORTED' THEN PD.Qty ELSE 0 END) as SortedQty --ML01
  FROM PICKDETAIL PD WITH (nolock)    
  left join orders OH (nolock) on PD.Orderkey=OH.orderkey  
  left join packtask(nolock) PT on PT.OrderKey=PD.OrderKey    
  -- left join DeviceProfile(nolock) CP on CP.DeviceID=PT.Station and CP.DevicePosition=PT.DevicePosition  
  where PD.pickslipno=@c_pickslipno    
  group by OH.LoadKey, OH.orderkey,OH.TrackingNo,PD.pickslipno,PD.Notes,PT.logicalname  --CS01 
   
END


GO