SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW V_GTMKioskASRSTask AS
SELECT TaskType = 'ASRSQC'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'F'
   ,   PanelLUOClass = ''
   ,   PanelMUOClass = 'u_kiosk_asrsqc_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = ''
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSCC'
   ,   PanelL  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'F'
   ,   PanelLUOClass = ''
   ,   PanelMUOClass = 'u_kiosk_asrscc_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = ''
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSPK'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'c'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'F'
   ,   PanelLUOClass = 'u_kiosk_asrspk_' + LOWER(SUBSTRING(Udf02,1,1))
   ,   PanelMUOClass = 'u_kiosk_asrspk_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = 'u_kiosk_asrspk_' + LOWER(SUBSTRING(Udf02,3,1))
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSPK'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'a'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'c'
   ,   LogicalMoveTo   = 'b'  --TKLIM Pallet should remain in A not B because user picking from A to B.
   ,   PickMethod = 'F'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'a' THEN 'u_kiosk_asrspk_cip_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrspk_cip_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'a' THEN 'u_kiosk_asrspk_cip_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSPK'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'a'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'c'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'R'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'a' THEN 'u_kiosk_asrspk_cip_rev_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrspk_cip_rev_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'a' THEN 'u_kiosk_asrspk_cip_rev_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
/*-----18-DEC-2015 YTWan: SOS#358912 - Project Merlion - GTM Kiosk Enhancement (START) -----*/
SELECT TaskType = 'ASRSPK'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'c'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'R'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'c' THEN 'u_kiosk_asrspk_rev_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrspk_rev_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'c' THEN 'u_kiosk_asrspk_rev_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSTRF'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'c'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'F'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'c' THEN 'u_kiosk_asrstrf_new_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrstrf_new_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'c' THEN 'u_kiosk_asrstrf_new_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSTRF'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'b'
   ,   LogicalPickTo   = 'c'
   ,   LogicalMoveFrom = 'a'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'R'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'c' THEN 'u_kiosk_asrstrf_new_rev_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrstrf_new_rev_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'c' THEN 'u_kiosk_asrstrf_new_rev_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
/*-----18-DEC-2015 YTWan: SOS#358912 - Project Merlion - GTM Kiosk Enhancement (END) -----*/
UNION ALL
SELECT TaskType = 'ASRSTRF'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'a'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'c'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'F'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'a' THEN 'u_kiosk_asrstrf_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrstrf_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'a' THEN 'u_kiosk_asrstrf_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'
UNION ALL
SELECT TaskType = 'ASRSTRF'
   ,   GTMWorkStation  = Code
   ,   LogicalPickFrom = 'a'
   ,   LogicalPickTo   = 'b'
   ,   LogicalMoveFrom = 'c'
   ,   LogicalMoveTo   = 'b'
   ,   PickMethod = 'R'
   ,   PanelLUOClass = CASE WHEN LOWER(LEFT(Udf02,1)) = 'a' THEN 'u_kiosk_asrstrf_rev_' + LOWER(SUBSTRING(Udf02,1,1))
                                                     ELSE '' END
   ,   PanelMUOClass = 'u_kiosk_asrstrf_rev_' + LOWER(SUBSTRING(Udf02,2,1))
   ,   PanelRUOClass = CASE WHEN LOWER(RIGHT(Udf02,1))= 'a' THEN 'u_kiosk_asrstrf_rev_' + LOWER(SUBSTRING(Udf02,3,1))
                                                     ELSE '' END
FROM CODELKUP WITH (NOLOCK)
WHERE LISTNAME = 'ASRSGTMWS'


GO